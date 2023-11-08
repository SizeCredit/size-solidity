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
    # NOTE: Unnecessary, only for debugging
    uid: int
    expectedFV = np.zeros(maxTime)
    unlocked = np.zeros(maxTime)
    dueFV = np.zeros(maxTime)

    def __post_init__(self):
        # NOTE: This is required to since the dataclass constructor does not create separate numpy arrays for different instances of this class (idk why)
        self.expectedFV = np.zeros(maxTime)
        self.unlocked = np.zeros(maxTime)
        self.dueFV = np.zeros(maxTime)


    def RANC(self, lockedStart = 0):
        res = np.zeros(maxTime)
        for i in range(self.context.time, len(res)):
            res[i] = (res[i-1] if i > self.context.time else lockedStart) + self.expectedFV[i] - self.unlocked[i] - self.dueFV[i]
        #     print(f"i={i}, self.expectedFV[i]={self.expectedFV[i]}, self.unlocked[i]={self.unlocked[i]} self.dueFV[i]={self.dueFV[i]}, res[i]={res[i]}")
        # print(f"res = {res}")
        return res

    def getDF(self, lockedStart=0):
        res = pd.DataFrame({
            'expectedFV': self.expectedFV,
            'dueFV': self.dueFV,
            'unlocked': self.unlocked,
            'RANC': self.RANC(lockedStart=lockedStart)
        })
        return res



@dataclass
class RealCollateral:
    free: float = 0
    locked: float = 0

    def lockAbs(self, amount):
        self.free += self.locked
        self.locked = 0
        if amount > self.free:
            print(f"WARNING: Collateral not enough, amount={amount}, self.free={self.free}")
            return False
        self.locked = amount
        self.free -= amount
        return True

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

    def transfer(self, creditorRealCollateral, amount: float):
        assert self.free >= amount, f"Collateral not enough"
        self.free -= amount
        creditorRealCollateral.free += amount



@dataclass
class User:
    context: Context
    cash: RealCollateral
    eth: RealCollateral
    schedule: Schedule  # Field will be initialized later
    # schedule: Schedule = field(init=False)  # Field will be initialized later
    totDebtCoveredByRealCollateral: float = 0.0

    # def __post_init__(self):
    #     self.schedule = Schedule(context=self.context)

    def collateralRatio(self):
        print(f"totDebtCoveredByRealCollateral = {self.totDebtCoveredByRealCollateral}")
        res = np.inf if self.totDebtCoveredByRealCollateral == 0 else self.cash.locked + self.eth.locked * self.context.price / self.totDebtCoveredByRealCollateral
        print(f"self.cash.locked={self.cash.locked}, self.eth.locked={self.eth.locked}, self.context.price={self.context.price}, res = {res}")
        return res

    def isLiquidatable(self):
        return self.collateralRatio() < CRLiquidation

    def RANC(self):
        return self.schedule.getDF(lockedStart=self.cash.locked)


@dataclass
class Offer:
    context: Context






@dataclass
class YieldCurve:
    timeBuckets: List[int]
    rates: List[float]

    @staticmethod
    def getFlatRate(rate: float, timeBuckets: List[int]):
        return YieldCurve(timeBuckets=timeBuckets, rates=[rate] * len(timeBuckets))


@dataclass
class LoanOffer(Offer):
    # context: Context
    lender: User
    maxAmount: float
    maxDueDate: int
    # ratePerTimeUnit: float
    curveRelativeTime: YieldCurve = None


    def getRate(self, dueDate):
        assert dueDate > self.context.time, "Due Date need to be in the future"
        deltaT = dueDate - self.context.time
        if deltaT > self.curveRelativeTime.timeBuckets[-1]:
            return False, 0
        if deltaT < self.curveRelativeTime.timeBuckets[0]:
            return False, 0
        _minIdx = [index for index in range(len(self.curveRelativeTime.timeBuckets)) if self.curveRelativeTime.timeBuckets[index] <= deltaT][-1]
        _maxIdx = [index for index in range(len(self.curveRelativeTime.timeBuckets)) if self.curveRelativeTime.timeBuckets[index] >= deltaT][0]
        x0, y0 = self.curveRelativeTime.timeBuckets[_minIdx], self.curveRelativeTime.rates[_minIdx]
        x1, y1 = self.curveRelativeTime.timeBuckets[_maxIdx], self.curveRelativeTime.rates[_maxIdx]
        y = y0 + (y1 - y0) * (dueDate - x0) / (x1 - x0) if x1 != x0 else y0
        return True, y

    # def getFinalRate(self, dueDate):
    #     assert dueDate > self.context.time, "Due Date need to be in the future"
    #     assert dueDate <= self.maxDueDate, "Due Date out of range"
    #     return self.ratePerTimeUnit * (dueDate - self.context.time)

class BorrowOffer(Offer):
    borrower: User
    amount: float
    dueDate: int
    rate: float
    virtualCollateralLoansIds: List[int]

    def getFV(self):
        return (1 + self.rate) * self.amount

@dataclass
class GenericLoan:
    # The Orderbook UID of the loan
    # uid: int
    lender: User
    borrower: User

    FV: float
    amountFVExited: float

    # def __post_init__(self):
    #     self.amountFVExited = 0

    def isFOL(self):
        return not hasattr(self, "fol")

    def maxExit(self):
        return self.FV - self.amountFVExited

    def perc(self):
        return (self.maxExit()) / self.FV if self.isFOL() else self.fol.FV

    def getDueDate(self):
        return self.DueDate if self.isFOL() else self.fol.DueDate

    # def getLender(self):
    #     return self.lender if self.isFOL() else self.fol.lender
    #
    # def getBorrower(self):
    #     return self.borrower if self.isFOL() else self.fol.borrower

    def getFOL(self):
        return self if self.isFOL() else self.fol

    def lock(self, amount):
        assert amount <= self.maxExit(), f"Amount={amount} too big for maxExit={self.maxExit()}"


@dataclass
class FOL(GenericLoan):
    context: Context
    # lender: User
    # borrower: User
    DueDate: int
    FVCoveredByRealCollateral: float
    repaid: bool = False

    # def perc(self):
    #     return (self.FV - self.amountFVExited) / self.FV

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
    # lender: User
    # borrower: User

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
    loanOffers: Dict[int, LoanOffer] = field(default_factory=dict)
    borrowOffers: Dict[int, BorrowOffer] = field(default_factory=dict)
    activeLoans: Dict[int, GenericLoan] = field(default_factory=dict)
    # activeFOLs: Dict[int, FOL] = field(default_factory=dict)
    # activeSOLs: Dict[int, SOL] = field(default_factory=dict)
    uidLoanOffers: int = 0
    uidBorrowOffers: int = 0
    uidLoans: int = 0

    def lendAsLimitOrder(self, offer: LoanOffer):
        self.loanOffers[self.uidLoanOffers] = offer
        self.uidLoanOffers += 1

    def borrowAsLimitOrder(self, offer: BorrowOffer):
        self.borrowOffers[self.uidBorrowOffers] = offer
        self.uidBorrowOffers += 1

    def createFOL(self, lender: User, borrower: User, FV: float, dueDate: int, FVCoveredByRealCollateral: float):
        self.activeLoans[self.uidLoans] = FOL(context=self.context, lender=lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=FVCoveredByRealCollateral, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1

    def createSOL(self, fol: FOL, lender: User, borrower: User, FV: float):
        self.activeLoans[self.uidLoans] = SOL(fol=fol, lender=lender, borrower=borrower, FV=FV, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1


    def borrowAsMarketOrder(self, borrower: User, offerId: int, amount: float, dueDate: int):
        offer = self.loanOffers[offerId]
        assert dueDate > self.context.time, "Due Date need to be in the future"
        assert amount <= offer.maxAmount, "Money is not enough"
        assert dueDate <= offer.maxDueDate, "Due Date out of range"
        assert offer.lender.cash.free >= amount, f"Lender has not enough free cash to lend out offer.lender.cash.free={offer.lender.cash.free}, amount={amount}"
        # deltaT = dueDate - self.context.time

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            return False, 0
        FV = (1 + rate) * amount
        # FV = (1 + offer.getFinalRate(dueDate=dueDate)) * amount
        # FV = (1 + offer.ratePerTimeUnit * deltaT) * amount
        print(f"FV = {FV}")

        # NOTE: This is required to compute the correct RANC, will be reverted if the TX fails
        borrower.schedule.dueFV[dueDate] += FV
        RANC = borrower.schedule.RANC(lockedStart=borrower.cash.locked)
        maxUSDCToLock = 0

        if not np.all(RANC >= 0):
            maxUserDebtUncovered = np.max(-1 * RANC)
            assert maxUserDebtUncovered > 0, "Unexpected"
            borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered
            maxETHToLock = (borrower.totDebtCoveredByRealCollateral / self.context.price) * CROpening
            print(f"pick() borrower.totDebtCoveredByRealCollateral = {borrower.totDebtCoveredByRealCollateral}")
            print(f"maxETHToLock = {maxETHToLock}")
            if not borrower.eth.lockAbs(amount=maxETHToLock):
                # TX Reverts
                borrower.schedule.dueFV[dueDate] -= FV
                print(f"WARNING: Virtual Collateral is not enough to take the loan")
                return False, 0

        # NOTE: Here loan can be taken so let's proceed with the other state modifications
        if amount == offer.maxAmount:
            del self.loanOffers[offerId]
        else:
            self.loanOffers[offerId].maxAmount -= amount
        offer.lender.schedule.expectedFV[dueDate] += FV
        offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
        return True, self.createFOL(lender=offer.lender, borrower=borrower, FV=FV, dueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock)
        # self.activeLoans[self.uidLoans] = FOL(context=self.context, lender=offer.lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock, amountFVExited=0)
        # # self.activeFOLs[self.uidLoans] = FOL(context=self.context, lender=offer.lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock, amountFVExited=0)
        # self.uidLoans += 1
        # return self.uidLoans-1


    def lendAsMarketOrderByExiting(self, lender: User, borrowOfferId: int):
        # TODO: Implement
        offer = self.borrowOffers[borrowOfferId]
        assert lender.cash.free >= offer.amount, f"Lender has not enough free cash to lend out lender.cash.free={lender.cash.free}, offer.amount={offer.amount}"
        # TODO: Finish implementing




    def borrowAsMarketOrderByExiting(self, borrower: User, offerId: int, amount: float, virtualCollateralLoansIds: List[int], dueDate: int = None):
        offer = self.loanOffers[offerId]
        # assert dueDate > self.context.time, "Due Date need to be in the future"
        assert amount <= offer.maxAmount, "Money is not enough"
        # assert dueDate <= offer.maxDueDate, "Due Date out of range"
        assert offer.lender.cash.free >= amount, f"Lender has not enough free cash to lend out offer.lender.cash.free={offer.lender.cash.free}, amount={amount}"
        # deltaT = dueDate - self.context.time

        # amountIn: Amount of future cashflow to exit
        # amountOut: Amount of cash to borrow at present time

        # NOTE: The `amountOutLeft` is going to be decreased as more and more SOLs are created
        amountOutLeft = amount

        # TODO: Create SOLs
        for loanId in virtualCollateralLoansIds:
            # Full amount borrowed
            if amountOutLeft == 0:
                break
            loan = self.activeLoans[loanId]
            if loan.lender != borrower:
                print(f"Warning: Skipping loanId={loanId} since it is not owned by borrower")
                continue
            dueDate = dueDate if dueDate is not None else loan.getDueDate()
            if dueDate > offer.maxDueDate:
                print(f"Warning: Skipping loanId={loanId} since it is due after the offer maxDueDate")
                continue
            if dueDate < loan.getDueDate():
                print(f"Warning: Skipping loanId={loanId} since it is due before the offer dueDate")
                continue
            temp, rate = offer.getRate(dueDate=dueDate)
            if not temp:
                print(f"WARNING: dueDate={dueDate} not available in the current offer")
                return False, 0
            r = (1 + rate)
            # r = (1 + offer.getFinalRate(dueDate=dueDate))
            amountInLeft = r * amountOutLeft
            deltaAmountIn = min(amountInLeft, self.activeLoans[loanId].maxExit())
            deltaAmountOut = deltaAmountIn / r
            self.createSOL(fol=loan.getFOL(), lender=offer.lender, borrower=borrower, FV=deltaAmountIn)
            loan.lock(deltaAmountIn)
            # NOTE: Transfer `deltaAmountOut` for each SOL created
            offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=deltaAmountOut)
            offer.maxAmount -= deltaAmountOut
            amountInLeft -= deltaAmountIn
            amountOutLeft -= deltaAmountOut

        # TODO: Cover the remaining amount with real collateral
        if amountOutLeft > 0:
            print(f"Final Check amountOutLeft = {amountOutLeft}")
            maxETHToLock = (amountOutLeft / self.context.price) * CROpening
            if not borrower.eth.lock(amount=maxETHToLock):
                # TX Reverts
                print(f"WARNING: Real Collateral is not enough to take the loan")
                return False, 0
            # TODO: Lock ETH to cover that amount
            borrower.totDebtCoveredByRealCollateral += amountOutLeft
            offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
        return True, 0


    def getBorrowerStatus(self, borrower: User):
        lockedStart = borrower.cash.locked + borrower.eth.locked * context.price
        return pd.DataFrame({
            'expectedFV': borrower.schedule.expectedFV,
            'dueFV': borrower.schedule.dueFV,
            'unlocked': borrower.schedule.unlocked,
            'RANC': borrower.schedule.RANC(lockedStart=lockedStart)
        })

    def exit(self, exitingLender: User, loanId: int, amount: float, offersIds: List[int], dueDate=None):
        # NOTE: The exit is equivalent to a spot swap for exact amount in wheres
        # - the exiting lender is the taker
        # - the other lenders are the makers
        # The swap traverses the `offersIds` as they if they were ticks with liquidity in an orderbook
        loan = self.activeLoans[loanId]
        dueDate = dueDate if dueDate is not None else loan.getDueDate()
        # loan = self.activeFOLs[loanId] if isFOL else self.activeSOLs[loanId]
        assert loan.lender == exitingLender, "Invalid lender"
        assert amount <= loan.maxExit(), "Amount too big"
        amountInLeft = amount
        for offerId in offersIds:
            # No more amountIn to swap
            if(amountInLeft == 0):
                break

            offer = self.loanOffers[offerId]
            # No liquidity to take in this bin
            if(offer.maxAmount == 0):
                continue
            temp, rate = offer.getRate(dueDate=dueDate)
            if temp == False:
                return False, 0
            r = (1 + rate)
            # r = (1 + offer.getFinalRate(dueDate=dueDate))
            maxDeltaAmountIn = r * offer.maxAmount
            deltaAmountIn = min(maxDeltaAmountIn, amountInLeft)
            deltaAmountOut = deltaAmountIn / r

            # Swap
            self.createSOL(fol=loan.getFOL(), lender=offer.lender, borrower=exitingLender, FV=deltaAmountIn)
            loan.lock(deltaAmountIn)
            offer.lender.cash.transfer(creditorRealCollateral=exitingLender.cash, amount=deltaAmountOut)
            offer.maxAmount -= deltaAmountOut
            amountInLeft -= deltaAmountIn
        return True, amountInLeft


    def repay(self, loanId, amount):
        fol = self.activeLoans[loanId]
        assert fol.isFOL(), "Invalid loan type"
        assert fol.FVCoveredByRealCollateral > 0, "Nothing to repay"
        assert fol.borrower.cash.free >= amount, f"Not enough free cash in the borrower balance fol.borrower.cash.free={fol.borrower.cash.free}, amount={amount}"
        assert amount >= fol.FVCoveredByRealCollateral, "Amount not sufficient"

        # NOTE: For logging purpose onlys
        excess = amount - fol.FVCoveredByRealCollateral

        # By default, all the future cashflow is considered locked
        # This means to unlock it, the lender need to run some computation
        fol.borrower.cash.free -= amount
        fol.lender.cash.locked += fol.FVCoveredByRealCollateral
        fol.borrower.totDebtCoveredByRealCollateral -= fol.FVCoveredByRealCollateral
        fol.FVCoveredByRealCollateral = 0


    def unlock(self, loanId: int, time: int, amount: float):
        loan = self.activeLoans[loanId]
        lender = loan.lender()
        lender.schedule.unlocked[time] += amount
        if not np.all(lender.schedule.RANC(nowTime=self.context.time) >= 0):
            # Revert TX
            lender.schedule.unlocked[time] -= amount
            assert False, f"Impossible to unlock loanId={loanId}, time={time}, amount={amount}"

    def _computeCollateralForDebt(self, amountUSDC: float) -> float:
        return amountUSDC / self.context.price

    def _liquidationSwap(self, liquidator: User, borrower: User, amountUSDC: float, amountETH: float):
        liquidator.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC)
        borrower.cash.lock(amount=amountUSDC)
        borrower.eth.unlock(amount=amountETH)
        borrower.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH)


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

        # liquidator.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC)
        # borrower.cash.lock(amount=amountUSDC)
        #
        # print(f"After borrower.cash.locked = {borrower.cash.locked}")
        #
        # print(f"Delta locked = {borrower.cash.locked - temp}")
        #
        # borrower.eth.unlock(amount=amountETH)
        # borrower.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH)
        borrower.totDebtCoveredByRealCollateral = 0
        return actualAmountETH, targetAmountETH


    def liquidateLoan(self, liquidator: User, loanId: int):
        # TODO: Implement it
        fol = self.activeLoans[loanId]
        assert fol.isFOL(), "Invalid loan type"
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




