@dataclass
class Context:
    time: int
    price: float

    def update(self, newTime: int, newPrice: float):
        assert newTime > self.time, f"Invalid Time time={newTime}, self.time={self.time}"
        self.time = newTime
        self.price = newPrice

@dataclass
class Schedule:
    context: Context
    expectedFV = np.zeros(maxTime)
    unlocked = np.zeros(maxTime)
    dueFV = np.zeros(maxTime)

    def RANC(self, lockedStart = 0):
        res = np.zeros(maxTime)
        for i in range(self.context.time, len(res)):
            res[i] = (res[i-1] if i > self.context.time else lockedStart) + self.expectedFV[i] - self.unlocked[i] - self.dueFV[i]
            print(f"i={i}, self.expectedFV[i]={self.expectedFV[i]}, self.unlocked[i]={self.unlocked[i]} self.dueFV[i]={self.dueFV[i]}, res[i]={res[i]}")
        print(f"res = {res}")
        return res

    def getDF(self, lockedStart=0):
        res = pd.DataFrame({
            'expectedFV': self.expectedFV,
            'dueFV': self.dueFV,
            'unlocked': self.unlocked,
            'RANC': self.RANC(nowTime=self.context.time, lockedStart=lockedStart)
        })
        return res



@dataclass
class RealCollateral:
    free: float = 0
    locked: float = 0

    def lock(self, amount):
        if amount <= self.free:
            self.free -= amount
            self.locked += amount
            return True
        else:
            print(f"Amount too big free={self.free}, amount={amount}")
            return False

    def unlock(self, amount):
        if amount <= self.locked:
            self.locked -= amount
            self.free += amount
            return True
        else:
            print(f"Amount too big free={self.free}, amount={amount}")
            return False

    def transfer(self, otherRealCollateral, amount: float):
        assert self.free >= amount, f"Collateral not enough"
        self.free -= amount
        otherRealCollateral.free += amount



@dataclass
class User:
    context: Context
    cash: RealCollateral
    eth: RealCollateral
    schedule: Schedule = field(init=False)  # Field will be initialized later
    totDebtCoveredByRealCollateral: float = 0.0

    def __post_init__(self):
        self.schedule = Schedule(context=self.context)

    def collateralRatio(self):
        print(f"totDebtCoveredByRealCollateral = {self.totDebtCoveredByRealCollateral}")
        res = np.inf if self.totDebtCoveredByRealCollateral == 0 else self.cash.locked + self.eth.locked * self.context.price / self.totDebtCoveredByRealCollateral
        print(f"self.cash.locked={self.cash.locked}, self.eth.locked={self.eth.locked}, self.context.price={self.context.price}, res = {res}")
        return res

    def isLiquidatable(self):
        return self.collateralRatio() < CRLiquidation


@dataclass
class LoanOffer:
    context: Context
    lender: User
    maxAmount: float
    maxDueDate: int
    # Assuming flat rate over all the due dates, will be changed later to support different rates for different due dates i.e. the yield curve
    ratePerTimeUnit: float

    def getFinalRate(self, dueDate):
        assert dueDate > self.context.time, "Due Date need to be in the future"
        assert dueDate <= self.maxDueDate, "Due Date out of range"
        return self.ratePerTimeUnit * (dueDate - self.context.time)

@dataclass
class GenericLoan:
    FV: float
    amountFVExited: float

    # def __post_init__(self):
    #     self.amountFVExited = 0


@dataclass
class FOL(GenericLoan):
    context: Context
    lender: User
    borrower: User
    # FV: float
    DueDate: int
    FVCoveredByRealCollateral: float

    def perc(self):
        return (self.FV - self.amountFVExited) / self.FV

    # This will be used to implement the v1 loan exit mechanism so FOL lender exiting to other lenders creating SOLs in the process
    # amountFVExited: float = 0

    # NOTE: When the loan reaches the due date, we call it expired and it is not liquidated in the sense the collateral is not sold and the debt closed,
    # but it is moved to the Variable Pool using the same collateral already deposited to back it
    def isExpired(self):
        return self.context.time >= self.dueDate

    # NOTE: Atm this is implemented in the Order Book
    # def isLiquidatable(self):
    #     # TODO: Implement
    #     # NOTE: A subset of FOLs can be eligible for liquidation if they have part of their FV that is not covered by other cashflows
    #     pass


@dataclass
class SOL(GenericLoan):
    fol: FOL
    lender: User

    def maxExit(self):
        return self.FV - self.amountFVExited

    def perc(self):
        return (self.maxExit()) / self.fol.FV

@dataclass
class VariableLoan:
    borrower: User
    amountUSDCLentOut: float
    amountCollateral: float



@dataclass
class VariablePool:
    context: Context
    reserveUSDC: float
    reserveETH: float
    activeLoans: Dict[int, VariableLoan] = field(default_factory=dict)



@dataclass
class AMM:
    reserveUSDC: float
    reserveETH: float
    fixedPrice: float = 0

    def instantPrice(self):
        return self.reserveUSDC / self.reserveETH if self.fixedPrice == 0 else self.fixedPrice

    def quote(self, isExactInput: bool, isAmountQuote: bool, amount: float):
        return self.instantPrice()

    def swap(self, isExactInput: bool, isAmountQuote: bool, amount: float):
        assert isExactInput == True and isAmountQuote == False, f"Unsupported"
        price = self.quote(isExactInput=isExactInput, isAmountQuote=isAmountQuote, amount=amount)
        amountOut = amount * price
        assert amountOut <= self.reserveUSDC, f"Reserves are not enough amount={amount}, self.reservesUSDC={self.reservesUSDC}"
        self.reservesUSDC -= amountOut
        self.reservesETH += amount


@dataclass
class LendingOB:
    context: Context
    offers: Dict[int, LoanOffer] = field(default_factory=dict)
    activeFOLs: Dict[int, FOL] = field(default_factory=dict)
    activeSOLs: Dict[int, SOL] = field(default_factory=dict)
    uidOffers: int = 0
    uidLoans: int = 0

    def place(self, offer):
        self.offers[self.uidOffers] = offer
        self.uidOffers += 1

    def pick(self, borrower, offerId, amount, dueDate):
        offer = self.offers[offerId]
        assert dueDate > self.context.time, "Due Date need to be in the future"
        assert amount <= offer.maxAmount, "Money is not enough"
        assert dueDate <= offer.maxDueDate, "Due Date out of range"
        assert offer.lender.cash.free >= amount, f"Lender has not enough free cash to lend out offer.lender.cash.free={offer.lender.cash.free}, amount={amount}"
        # deltaT = dueDate - self.context.time

        FV = (1 + offer.getFinalRate(dueDate=dueDate)) * amount
        # FV = (1 + offer.ratePerTimeUnit * deltaT) * amount
        print(f"FV = {FV}")

        borrower.schedule.dueFV[dueDate] += FV
        RANC = borrower.schedule.RANC(lockedStart=borrower.cash.locked)
        maxUSDCToLock = 0
        if np.all(RANC >= 0):
            offer.lender.schedule.expectedFV[dueDate] += FV

            if amount == offer.maxAmount:
                del self.offers[offerId]
            else:
                self.offers[offerId].maxAmount -= amount
        else:
            maxUserDebtUncovered = np.max(-1 * RANC)
            assert maxUserDebtUncovered > 0, "Unexpected"
            borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered
            maxETHToLock = (borrower.totDebtCoveredByRealCollateral / self.context.price) * CROpening
            if not borrower.eth.lock(amount=maxETHToLock):
                # TX Reverts
                borrower.schedule.dueFV[dueDate] -= FV
                assert False, "Virtual Collateral is not enough to take the loan"
        offer.lender.cash.transfer(otherRealCollateral=borrower.cash, amount=amount)
        # offer.lender.cash.free -= amount
        # borrower.cash.free += amount
        self.activeFOLs[self.uidLoans] = FOL(context=self.context, lender=offer.lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1

    def getBorrowerStatus(self, borrower: User):
        lockedStart = borrower.cash.locked + borrower.eth.locked * context.price
        return pd.DataFrame({
            'expectedFV': borrower.schedule.expectedFV,
            'dueFV': borrower.schedule.dueFV,
            'unlocked': borrower.schedule.unlocked,
            'RANC': borrower.schedule.RANC(lockedStart=lockedStart)
        })

    def exit(self, lender: User, isFOL: bool, loanId: int, amount: float, offersIds: List[int]):
        loan = self.activeFOLs[loanId] if isFOL else self.activeSOLs[loanId]
        assert loan.lender == lender, "Invalid lender"
        assert amount <= loan.maxExit(), "Amount too big"
        amountLeft = amount
        for offerId in offersIds:
            offer = self.offers[offerId]


    def repay(self, loanId, amount):
        fol = self.activeFOLs[loanId]
        assert fol.FVCoveredByRealCollateral > 0, "Nothing to repay"
        assert fol.borrower.cash.free >= amount, f"Not enough free cash in the borrower balance fol.borrower.cash.free={fol.borrower.cash.free}, amount={amount}"
        assert amount >= fol.FVCoveredByRealCollateral, "Amount not sufficient"
        excess = amount - fol.FVCoveredByRealCollateral

        # By default, all the future cashflow is considered locked
        # This means to unlock it, the lender need to run some computation
        fol.borrower.cash.free -= amount
        fol.lender.cash.locked += fol.FVCoveredByRealCollateral
        fol.borrower.totDebtCoveredByRealCollateral -= fol.FVCoveredByRealCollateral
        fol.FVCoveredByRealCollateral = 0

    def unlock(self, loanId: int, time: int, amount: float):
        loan = self.activeFOLs[loanId]
        loan.lender.schedule.unlocked[time] += amount
        if not np.all(loan.lender.schedule.RANC(nowTime=self.context.time) >= 0):
            # Revert TX
            loan.lender.schedule.unlocked[time] -= amount
            assert False, f"Impossible to unlock loanId={loanId}, time={time}, amount={amount}"

    def _computeCollateralForDebt(self, amountUSDC: float) -> float:
        return amountUSDC / self.context.price

    def _liquidationSwap(self, liquidator: User, borrower: User, amountUSDC: float, amountETH: float):
        liquidator.cash.transfer(otherRealCollateral=borrower.cash, amount=amountUSDC)
        borrower.cash.lock(amount=amountUSDC)
        borrower.eth.unlock(amount=amountETH)
        borrower.eth.transfer(otherRealCollateral=liquidator.eth, amount=amountETH)


    def liquidateBorrower(self, liquidator: User, borrower: User):
        assert borrower.isLiquidatable(), f"Borrower is not liquidatable"
        assert liquidator.cash.free >= borrower.totDebtCoveredByRealCollateral, f"Liquidator has not enough money liquidator.cash.free={liquidator.cash.free}, borrower.totDebtCoveredByRealCollateral={borrower.totDebtCoveredByRealCollateral}"

        temp = borrower.cash.locked
        print(f"Before borrower.cash.locked = {borrower.cash.locked}")


        # NOTE: The `totDebtCoveredByRealCollateral` is already partially covered by the cash.locked so we need to transfer only the USDC for the part covered by ETH
        amountUSDC = borrower.totDebtCoveredByRealCollateral - borrower.cash.locked

        targetAmountETH = self._computeCollateralForDebt(amountUSDC=amountUSDC)
        actualAmountETH = min(targetAmountETH, borrower.eth.locked)
        if(actualAmountETH < targetAmountETH):
            print(f"WARNING: Liquidation at loss, missing {targetAmountETH - actualAmountETH}")
        self._liquidationSwap(liquidator=liquidator, borrower=borrower, amountUSDC=amountUSDC, amountETH=actualAmountETH)

        # liquidator.cash.transfer(otherRealCollateral=borrower.cash, amount=amountUSDC)
        # borrower.cash.lock(amount=amountUSDC)
        #
        # print(f"After borrower.cash.locked = {borrower.cash.locked}")
        #
        # print(f"Delta locked = {borrower.cash.locked - temp}")
        #
        # borrower.eth.unlock(amount=amountETH)
        # borrower.eth.transfer(otherRealCollateral=liquidator.eth, amount=amountETH)
        borrower.totDebtCoveredByRealCollateral = 0
        return actualAmountETH, targetAmountETH


    def liquidateLoan(self, liquidator: User, loanId: int):
        # TODO: Implement it
        fol = self.activeFOLs[loanId]
        RANC = fol.borrower.schedule.RANC()
        assert RANC[fol.DueDate] < 0, f"Loan is not liquidatable"
        # NOTE: We assume all the negative delta cashflow for this time bucket belongs to this FOL
        # In general, at given t time bucket with RANC(t) < 0, there are N>=1 FOLs with due date t, so instead of assigning to each one RANC(t)/N we assign the full RANC(t) to this FOL

        loanDebtUncovered = -1 * RANC[fol.DueDate]
        totBorroweDebt = fol.borrower.totDebtCoveredByRealCollateral
        loanCollateral = fol.borrower.eth.locked * loanDebtUncovered / totBorroweDebt
        # loanCollateralRatio = loanCollateral / loanDebtUncovered
        # NOTE: This is equivalent to the borrower collateral ratio as expected, therefore there is no need to compute that

        assert fol.borrower.isLiquidatable(), f"Borrower is not liquidatable"
        assert liquidator.cash.free >= loanDebtUncovered, f"Liquidator has not enough money liquidator.cash.free={liquidator.cash.free}, RANC[fol.DueDate]={RANC[fol.DueDate]}"
        targetAmountETH = self._computeCollateralForDebt(amountUSDC=loanDebtUncovered)
        actualAmountETH = min(targetAmountETH, fol.borrower.eth.locked)
        if(actualAmountETH < targetAmountETH):
            print(f"WARNING: Liquidation at loss, missing {targetAmountETH - actualAmountETH}")

        self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=loanDebtUncovered, amountETH=loanCollateral)




