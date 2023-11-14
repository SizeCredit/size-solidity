
@dataclass
class Params:
    maxTime: int = 12
    CROpening: float = 1.5
    CRLiquidation: float = 1.3

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

    def lock(self, amount, dryRun=False):
        if amount <= self.free:
            if not dryRun:
                self.free -= amount
                self.locked += amount
            return True
        else:
            print(f"Amount too big free={self.free}, amount={amount}")
            return False

    def unlock(self, amount, dryRun=False):
        if amount <= self.locked:
            if not dryRun:
                self.locked -= amount
                self.free += amount
            return True
        else:
            print(f"Amount too big free={self.free}, amount={amount}")
            return False

    def transfer(self, creditorRealCollateral, amount: float, dryRun=False):
        if self.free < amount:
            print(f"self.free={self.free}, amount={amount}")
            return False
        if not dryRun:
            self.free -= amount
            creditorRealCollateral.free += amount
        return True



@dataclass
class User:
    context: Context
    cash: RealCollateral
    eth: RealCollateral
    # schedule: Schedule  # Field will be initialized later
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

    # def RANC(self):
    #     return self.schedule.getDF(lockedStart=self.cash.locked)


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

    def getAssignedCollateral(self):
        return self.borrower.eth.locked * self.FV / self.borrower.totDebtCoveredByRealCollateral if self.borrower.totDebtCoveredByRealCollateral != 0 else 0

    def lock(self, amount: float):
        if amount > self.maxExit():
            print(f"WARNING: amount={amount} is too big, self.maxExit()={self.maxExit()}")
            return False
        self.amountFVExited += amount
        return True




@dataclass
class FOL(GenericLoan):
    context: Context
    # lender: User
    # borrower: User
    DueDate: int
    # FVCoveredByRealCollateral: float
    repaid: bool = False

    # def perc(self):
    #     return (self.FV - self.amountFVExited) / self.FV

    # This will be used to implement the v1 loan exit mechanism so FOL lender exiting to other lenders creating SOLs in the process
    # amountFVExited: float = 0

    # NOTE: When the loan reaches the due date, we call it expired and it is not liquidated in the sense the collateral is not sold and the debt closed,
    # but it is moved to the Variable Pool using the same collateral already deposited to back it
    def isExpired(self):
        return self.context.time >= self.dueDate


@dataclass
class SOL(GenericLoan):
    fol: FOL
    # lender: User
    # borrower: User

class VariablePool:
    pass

@dataclass
class VariableLoan:
    context: Context
    pool: VariablePool
    borrower: User
    amountUSDCLentOut: float
    amountCollateral: float
    startTime: int
    repaid: bool = False

    def getDebtCurrent(self):
        return self.amountUSDCLentOut * (1 + self.pool.getRatePerUnitTime() * (self.context.time - self.startTime))

    def getCollateralRatio(self):
        return self.amountCollateral * self.context.price / self.getDebtCurrent()



@dataclass
class VariablePool:
    context: Context
    minCollateralRatio: float
    cash: RealCollateral
    eth: RealCollateral
    activeLoans: Dict[int, VariableLoan] = field(default_factory=dict)
    uidLoans: int = 0


    # NOTE: Rate per time unit
    def getRatePerUnitTime(self):
        # TODO: Fix this
        return 1 / 1 + np.exp(- self.cash.free)

    def takeLoan(self, borrower: User, amountUSDC: float, amountETH: float, dryRun=False):
        if  not self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC, dryRun=True):
            print(f"No enough reserves amountUSDC={amountUSDC}, self.cash.free={self.cash.free}")
            return False, 0
        if not borrower.eth.lock(amount=amountETH, dryRun=True):
            print(f"No enough reserves amountETH={amountETH}, borrower.eth.free={borrower.eth.free}")
            return False, 0
        if (amountUSDC * self.getRatePerUnitTime()) * self.minCollateralRatio > amountETH * self.context.price:
            print(f"Collateral not enough amountUSDC={amountUSDC}, amountETH={amountETH}, self.context.price={self.context.price}")
            return False, 0
        if dryRun:
            return True, 0
        self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC)
        borrower.eth.lock(amount=amountETH)
        self.activeLoans[self.uidLoans] = VariableLoan(
            context=self.context,
            pool=self,
            borrower=borrower,
            amountUSDCLentOut=amountUSDC,
            amountCollateral=amountETH,
            startTime=self.context.time)
        self.uidLoans += 1
        return True, self.uidLoans-1

    def repay(self, loanId: int):
        loan = self.activeLoans[loanId]
        if loan.repaid:
            print(f"Loan already repaid loanId={loanId}")
            return False
        if not loan.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=loan.getDentCurrent(), dryRun=True):
            print(f"Not enough cash to repay loanId={loanId}")
            return False

        if not loan.borrower.eth.unlock(amount=loan.amountCollateral, dryRun=True):
            print(f"Not enough ETH to repay loanId={loanId}")
            return False

        loan.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=loan.getDentCurrent())
        loan.borrower.eth.unlock(amount=loan.amountCollateral)
        loan.repaid = True
        return True



@dataclass
class AMM:
    cash: RealCollateral
    eth: RealCollateral
    fixedPrice: float = 0

    def instantPrice(self):
        return self.cash.free / self.eth.free if self.fixedPrice == 0 else self.fixedPrice

    def quote(self, isExactInput: bool, isAmountQuote: bool, amount: float):
        return self.instantPrice()

    def swap(self, caller: User, isExactInput: bool, isAmountQuote: bool, amount: float):
        assert isExactInput == True and isAmountQuote == False, f"Unsupported"
        price = self.quote(isExactInput=isExactInput, isAmountQuote=isAmountQuote, amount=amount)
        amountOut = amount * price
        if not self.cash.transfer(creditorRealCollateral=caller.cash, amount=amountOut, dryRun=True):
            print(f"Reserves are not enough amount={amountOut}, self.cash.free={self.cash.free}")
            return False, 0
        if not caller.eth.transfer(creditorRealCollateral=self.eth, amount=amount, dryRun=True):
            print(f"Reserves are not enough amount={amount}, self.cash.free={caller.eth.free}")
            return False, 0
        self.cash.transfer(creditorRealCollateral=caller.cash, amount=amountOut, dryRun=True)
        caller.eth.transfer(creditorRealCollateral=self.eth, amount=amount, dryRun=True)
        return True, 0


@dataclass
class LendingOB:
    context: Context
    vp: VariablePool
    cash: RealCollateral
    eth: RealCollateral
    usersCash: Dict[User, float] = field(default_factory=dict)
    usersETH: Dict[User, float] = field(default_factory=dict)
    loanOffers: Dict[int, LoanOffer] = field(default_factory=dict)
    borrowOffers: Dict[int, BorrowOffer] = field(default_factory=dict)
    activeLoans: Dict[int, GenericLoan] = field(default_factory=dict)
    uidLoanOffers: int = 0
    uidBorrowOffers: int = 0
    uidLoans: int = 0

    def deposit(self, user: User, amount: float, isUSDC: bool):
        if isUSDC:
            if not user.cash.transfer(creditorRealCollateral=self.cash, amount=amount,dryRun=True):
                return False, 0
            user.cash.transfer(creditorRealCollateral=self.cash, amount=amount)
            self.usersCash[user] += amount
        else:
            if not user.eth.transfer(creditorRealCollateral=self.eth, amount=amount,dryRun=True):
                return False, 0
            user.eth.transfer(creditorRealCollateral=self.eth, amount=amount)
            self.usersETH[user] += amount


    def withdraw(self, user: User, amount: float, isUSDC: bool):
        if isUSDC:
            if not self.cash.transfer(creditorRealCollateral=user.cash, amount=amount,dryRun=True):
                return False, 0
            self.cash.transfer(creditorRealCollateral=user.cash, amount=amount)
            self.usersCash[user] -= amount
        else:
            if not self.eth.transfer(creditorRealCollateral=user.eth, amount=amount,dryRun=True):
                return False, 0
            self.eth.transfer(creditorRealCollateral=user.eth, amount=amount)
            self.usersETH[user] -= amount


    def lendAsLimitOrder(self, offer: LoanOffer):
        self.loanOffers[self.uidLoanOffers] = offer
        self.uidLoanOffers += 1

    def borrowAsLimitOrder(self, offer: BorrowOffer):
        self.borrowOffers[self.uidBorrowOffers] = offer
        self.uidBorrowOffers += 1

    def createFOL(self, lender: User, borrower: User, FV: float, dueDate: int):
        self.activeLoans[self.uidLoans] = FOL(context=self.context, lender=lender, borrower=borrower, FV=FV, DueDate=dueDate, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1

    def createSOL(self, fol: FOL, lender: User, borrower: User, FV: float):
        self.activeLoans[self.uidLoans] = SOL(fol=fol, lender=lender, borrower=borrower, FV=FV, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1


    # def borrowAsMarketOrderWithRANC(self, borrower: User, offerId: int, amount: float, dueDate: int):
    #     offer = self.loanOffers[offerId]
    #     assert dueDate > self.context.time, "Due Date need to be in the future"
    #     assert amount <= offer.maxAmount, "Money is not enough"
    #     assert dueDate <= offer.maxDueDate, "Due Date out of range"
    #     assert offer.lender.cash.free >= amount, f"Lender has not enough free cash to lend out offer.lender.cash.free={offer.lender.cash.free}, amount={amount}"
    #     # deltaT = dueDate - self.context.time
    #
    #     temp, rate = offer.getRate(dueDate=dueDate)
    #     if not temp:
    #         return False, 0
    #     FV = (1 + rate) * amount
    #     # FV = (1 + offer.getFinalRate(dueDate=dueDate)) * amount
    #     # FV = (1 + offer.ratePerTimeUnit * deltaT) * amount
    #     print(f"FV = {FV}")
    #
    #     # NOTE: This is required to compute the correct RANC, will be reverted if the TX fails
    #     borrower.schedule.dueFV[dueDate] += FV
    #     RANC = borrower.schedule.RANC(lockedStart=borrower.cash.locked)
    #     maxUSDCToLock = 0
    #
    #     if not np.all(RANC >= 0):
    #         maxUserDebtUncovered = np.max(-1 * RANC)
    #         assert maxUserDebtUncovered > 0, "Unexpected"
    #         borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered
    #         maxETHToLock = (borrower.totDebtCoveredByRealCollateral / self.context.price) * CROpening
    #         print(f"pick() borrower.totDebtCoveredByRealCollateral = {borrower.totDebtCoveredByRealCollateral}")
    #         print(f"maxETHToLock = {maxETHToLock}")
    #         if not borrower.eth.lockAbs(amount=maxETHToLock):
    #             # TX Reverts
    #             borrower.schedule.dueFV[dueDate] -= FV
    #             print(f"WARNING: Virtual Collateral is not enough to take the loan")
    #             return False, 0
    #
    #     # NOTE: Here loan can be taken so let's proceed with the other state modifications
    #     if amount == offer.maxAmount:
    #         del self.loanOffers[offerId]
    #     else:
    #         self.loanOffers[offerId].maxAmount -= amount
    #     offer.lender.schedule.expectedFV[dueDate] += FV
    #     offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
    #     return True, self.createFOL(lender=offer.lender, borrower=borrower, FV=FV, dueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock)
    #     # self.activeLoans[self.uidLoans] = FOL(context=self.context, lender=offer.lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock, amountFVExited=0)
    #     # # self.activeFOLs[self.uidLoans] = FOL(context=self.context, lender=offer.lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=maxUSDCToLock, amountFVExited=0)
    #     # self.uidLoans += 1
    #     # return self.uidLoans-1


    def lendAsMarketOrderByExiting(self, lender: User, borrowOfferId: int):
        # TODO: Implement
        offer = self.borrowOffers[borrowOfferId]
        assert lender.cash.free >= offer.amount, f"Lender has not enough free cash to lend out lender.cash.free={lender.cash.free}, offer.amount={offer.amount}"
        # TODO: Finish implementing




    def borrowAsMarketOrder(self, borrower: User, offerId: int, amount: float, virtualCollateralLoansIds: List[int] = [], dueDate: int = None):
        offer = self.loanOffers[offerId]
        if dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        if amount > offer.maxAmount:
            print(f"Money is not enough amount={amount}, offer.maxAmount={offer.maxAmount}")
            return False, 0
        if dueDate > offer.maxDueDate:
            print(f"Due Date out of range dueDate={dueDate}, offer.maxDueDate={offer.maxDueDate}")
            return False, 0
        if offer.lender.cash.free < amount:
            print(f"Lender has not enough free cash to lend out offer.lender.cash.free={offer.lender.cash.free}, amount={amount}")
            return False, 0


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
            temp = loan.lock(deltaAmountIn)
            if not temp:
                return False
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
            self.createFOL(lender=offer.lender, borrower=borrower, FV=amountOutLeft, dueDate=dueDate)
            self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
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

    def _moveToVariablePool(self, loanId: int, dryRun=True):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print(f"WARNING: Invalid loan type")
            return False
        collateralToTransfer = fol.getAsignedCollateral()
        if not fol.borrower.eth.unlock(collateralToTransfer, dryRun=dryRun):
            print(f"WARNING: Not enough ETH to transfer")
            return False
        if not self.vp.takeLoan(
                borrower=fol.borrower,
                amountUSDC=fol.FVCoveredByRealCollateral,
                amountETH=collateralToTransfer,
                dryRun=dryRun):
            print(f"WARNING: Not enough reserves to transfer")
            return False
        # TODO: Finish implementing

    def moveToVariablePool(self, loanId: int):
        if self._moveToVariablePool(loanId=loanId, dryRun=True):
            return self._moveToVariablePool(loanId=loanId, dryRun=False)
        else:
            return False
        # TODO: Finish implementing

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
        # TODO: Finish implementing
        return False, 0
        # # TODO: Implement it
        # fol = self.activeLoans[loanId]
        # assert fol.isFOL(), "Invalid loan type"
        # RANC = fol.borrower.schedule.RANC()
        # assert RANC[fol.DueDate] < 0, f"Loan is not liquidatable"
        # # NOTE: We assume all the negative delta cashflow for this time bucket belongs to this FOL
        # # In general, at given t time bucket with RANC(t) < 0, there are N>=1 FOLs with due date t, so instead of assigning to each one RANC(t)/N we assign the full RANC(t) to this FOL
        #
        # loanDebtUncovered = -1 * RANC[fol.DueDate]
        # totBorroweDebt = fol.borrower.totDebtCoveredByRealCollateral
        # loanCollateral = fol.borrower.eth.locked * loanDebtUncovered / totBorroweDebt
        # # loanCollateralRatio = loanCollateral / loanDebtUncovered
        # # NOTE: This is equivalent to the borrower collateral ratio as expected, therefore there is no need to compute that
        #
        # assert fol.borrower.isLiquidatable(), f"Borrower is not liquidatable"
        # assert liquidator.cash.free >= loanDebtUncovered, f"Liquidator has not enough money liquidator.cash.free={liquidator.cash.free}, RANC[fol.DueDate]={RANC[fol.DueDate]}"
        # targetAmountETH = self._computeCollateralForDebt(amountUSDC=loanDebtUncovered)
        # actualAmountETH = min(targetAmountETH, fol.borrower.eth.locked)
        # if(actualAmountETH < targetAmountETH):
        #     print(f"WARNING: Liquidation at loss, missing {targetAmountETH - actualAmountETH}")
        #
        # self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=loanDebtUncovered, amountETH=loanCollateral)
        #
        #




class Test:
    def __init__(self):
        self.params = Params()
    def setup(self):
        self.context = Context(
            price=100,
            time=0
        )
        self.bob = User(context=self.context,
                        cash=RealCollateral(free=100, locked=0),
                        eth=RealCollateral(free=100, locked=0))
        self.alice = User(context=self.context,
             cash=RealCollateral(free=100, locked=0),
             eth=RealCollateral(free=100, locked=0))

        self.james = User(context=self.context,
             cash=RealCollateral(free=100, locked=0),
             eth=RealCollateral(free=100, locked=0))

        self.vp = VariablePool(context=self.context, cash=RealCollateral(free=100000, locked=0), eth=RealCollateral(),  minCollateralRatio=self.params.CRLiquidation)
        self.ob = LendingOB(context=self.context, vp=self.vp, cash=RealCollateral(free=100000, locked=0), eth=RealCollateral())

    def init1(self):
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=context,
            lender=alice,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(self.params.maxTime))
        ))
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.james, offerId=0, amount=100, dueDate=6)
        assert temp, "borrowAsMarketOrder failed"
        assert len(self.ob.activeLoans) > 0, f"len(ob.activeLoans) = {len(self.ob.activeLoans)}"
        loan = self.ob.activeLoans[0]
        assert loan.maxExit() == loan.FV

        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(self.params.maxTime))
        ))

    def test1(self):
        res, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, offerId=0, amount=100, dueDate=6, virtualCollateralLoansIds=[0])
        assert res

