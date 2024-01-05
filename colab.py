from enum import Enum
from dataclasses import dataclass, field

# Related Colab
# https://colab.research.google.com/drive/1vJGucnsxFABB3BVWw6ErJ65pVIqkMrBd?usp=sharing#scrollTo=A5orSmPV-Hrr

def myAssert(condition, message, withAssert=True):
    if withAssert:
        assert condition, message
    else:
        if not condition:
            print(message)
            return False
    return True


# State Changes
# 1 --> 2
# 1,2 --> 3
class LoanStates(Enum):
    # When the loan is started
    ACTIVE = 1
    # When maturity is reached
    # If the loan is not repaid and the CR is sufficient, it is moved to the Variable Pool
    # Otherwise it is eligible for liquidation but if the CR < 100% then it will remain in the overdue state until the CR is > 100% or the lenders perform self liquidation
    OVERDUE = 2
    # When the loan is repaid either by the borrower or by the liquidator
    REPAID = 3
    CLAIMED = 4

@dataclass
class Params:
    maxTime: int = 12
    CROpening: float = 1.5
    CRLiquidation: float = 1.3

@dataclass
class Context:
    params: Params
    time: int
    price: float

    def update(self, newTime: int, newPrice: float):
        assert newTime > self.time, f"Invalid Time time={newTime}, self.time={self.time}"
        self.time = newTime
        self.price = newPrice

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
    uid: str
    context: Context
    cash: RealCollateral
    eth: RealCollateral
    # schedule: Schedule  # Field will be initialized later
    # schedule: Schedule = field(init=False)  # Field will be initialized later
    totDebtCoveredByRealCollateral: float = 0.0


@dataclass
class Offer:
    context: Context

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



    # def getFinalRate(self, dueDate):
    #     assert dueDate > self.context.time, "Due Date need to be in the future"
    #     assert dueDate <= self.maxDueDate, "Due Date out of range"
    #     return self.ratePerTimeUnit * (dueDate - self.context.time)

@dataclass
class BorrowOffer(Offer):
    borrower: User
    maxAmount: float
    curveRelativeTime: YieldCurve = None
    # NOTE: These ones are replaced by the yield curve
    # dueDate: int
    # rate: float
    virtualCollateralLoansIds: List[int] = field(default_factory=list)

    def getFV(self):
        return (1 + self.rate) * self.amount

@dataclass
class GenericLoan:
    context: Context
    # The Orderbook UID of the loan
    # uid: int
    lender: User
    borrower: User
    FV: float

    # def __post_init__(self):
    #     self.claimed = False

    def isFOL(self):
        return not hasattr(self, "fol")

    def isOverdue(self):
        return self.context.time > self.getDueDate()

    # def isLiquidatable(self):
    #     return self.borrower.isLiquidatable()

    # NOTE: Lender Credit
    # NOTE: There is an asymmetry between the lender credit and the borrower debt, because of the exit mechanism
    def getCredit(self):
        # This shows where the future cashflows are going to
        # The FV is the total credit then
        # - some of it can be exited i.e. exchanged for cash and
        # - some of it can be claimed i.e. cashed out
        return self.FV - self.amountFVExited

    def isRepaid(self):
        return self.repaid if self.isFOL() else self.fol.repaid

    def perc(self):
        return (self.getCredit()) / self.FV if self.isFOL() else self.fol.FV

    # NOTE: Borrower Debt
    def getDebt(self, inCollateral=False):
        return self.FV if not inCollateral else self.FV / self.context.price

    def getDueDate(self):
        return self.DueDate if self.isFOL() else self.fol.DueDate

    # def getLender(self):
    #     return self.lender if self.isFOL() else self.fol.lender
    #
    # def getBorrower(self):
    #     return self.borrower if self.isFOL() else self.fol.borrower

    def getFOL(self):
        return self if self.isFOL() else self.fol

    def getState(self):
        assert self.amountFVExited <= self.FV, "This should never happen"
        if self.amountFVExited == self.FV:
            return LoanStates.CLAIMED
        if self.isRepaid():
            return LoanStates.REPAID
        if self.isOverdue():
            return LoanStates.OVERDUE
        else:
            return LoanStates.ACTIVE

        # if self.isRepaid():
        #     if self.amountFVExited == self.FV:
        #         return LoanStates.CLAIMED
        #     return LoanStates.REPAID
        # if self.isOverdue():
        #     return LoanStates.OVERDUE
        # else:
        #     return LoanStates.ACTIVE

    # def getAssignedCollateral(self):
    #     return self.borrower.eth.locked * self.FV / self.borrower.totDebtCoveredByRealCollateral if self.borrower.totDebtCoveredByRealCollateral != 0 else 0

    def lock(self, amount: float, dryRun=False):
        if amount > self.getCredit():
            print(f"WARNING: amount={amount} is too big, self.getCredit()={self.getCredit()}")
            return False
        if not dryRun:
            self.amountFVExited += amount
            assert self.amountFVExited <= self.FV, "This should never happen"
        return True

    def reduceDebt(self, amount: float, dryRun=False):
        if amount > self.getCredit():
            print(f"WARNING: amount={amount} is too big, self.getDebt()={self.getDebt()}")
            return False
        if not dryRun:
            self.FV -= amount
            # NOTE: This guarantees that `loan.FV >= loan.amountFVExited` is always true
            # NOTE: Even after debt reduction, it should be guaranteed that `FOL.FV == Sum of all SOL.credit()`
            assert self.getCredit() >= 0, "This should never happen"

            self.borrower.totDebtCoveredByRealCollateral -= amount
            assert self.borrower.totDebtCoveredByRealCollateral >= 0, "This should never happen"
        return True




@dataclass
class FOL(GenericLoan):
    # lender: User
    # borrower: User
    DueDate: int
    # Deprecated as related to the RANC approach
    # FVCoveredByRealCollateral: float
    repaid: bool = False
    claimed: bool = False
    amountFVExited: float = 0

    # NOTE: When the loan reaches the due date, we call it expired and it is not liquidated in the sense the collateral is not sold and the debt closed,
    # but it is moved to the Variable Pool using the same collateral already deposited to back it
    def isExpired(self):
        return self.context.time >= self.dueDate



@dataclass
class SOL(GenericLoan):
    fol: FOL
    # lender: User
    # borrower: User
    amountFVExited: float = 0


class VariableLoan:
    pass

@dataclass
class VariablePool:
    context: Context
    minCollateralRatio: float
    cash: RealCollateral
    eth: RealCollateral
    deposits: Dict[User, float] = field(default_factory=dict)
    loans: Dict[int, VariableLoan] = field(default_factory=dict)
    uidLoans: int = 0
    # Using the same accounting technique of Aave V3
    liquidityIndex = 1
    totDeposits: float = 0
    totLentOut: float = 0
    minRate: float = 0.1
    maxRate: float = 1
    slope: float = 0.1
    turningPoint: float = 0.9

    def setLendingOB(self, ob):
        self.ob = ob

    def getUtilizationRatio(self):
        res = self.totLentOut / self.totDeposits if self.totDeposits != 0 else 0
        assert res >= 0 and res <= 1, "This should never happen"
        return res
    def getInterestRate(self):
        ur = self.getUtilizationRatio()
        maxLowSlopeRate = self.minRate + self.slope * ur
        if ur <= self.turningPoint:
            return maxLowSlopeRate
        else:
            slopeHigh = (self.maxRate - maxLowSlopeRate) / (1 - self.turningPoint)
            return maxLowSlopeRate + slopeHigh * (ur - self.turningPoint)

    def borrow(self, borrower: User, amountLent: float, amountCollateral: float, recipientOfCash=None, providerOfCollateral=None, withAssert=True):
        if not myAssert(amountLent > 0, "Can't borrow 0", withAssert):
            return False
        BorrowerCROpening = amountCollateral * self.context.price / amountLent
        CROpening = self.context.params.CROpening
        if not myAssert(BorrowerCROpening >= CROpening, f"BorrowerCROpening={BorrowerCROpening}, CROpening={CROpening}", withAssert):
            return False
        recipient = borrower if recipientOfCash is None else recipientOfCash
        provider = borrower if providerOfCollateral is None else providerOfCollateral
        if not myAssert(self.cash.transfer(creditorRealCollateral=recipient.cash, amount=amountLent, dryRun=False), "Not enough reserves", withAssert):
            return False
        if not myAssert(provider.eth.transfer(creditorRealCollateral=self.eth, amount=amountCollateral, dryRun=False), "Not enough collateral", withAssert):
            return False
        loan = VariableLoan(
            pool=self,
            borrower=borrower,
            amountUSDCLentOut=amountLent,
            scaledAmountUSDCLentOut=amountLent / self.liquidityIndex,
            amountCollateral=amountCollateral,
            startTime=self.context.time
        )
        self.loans[self.uidLoans] = loan
        self.uidLoans += 1
        return True

    def isLiquidatable(self, loanId: int):
        loan = self.loans[loanId]
        return (loan.repaid == False) and (loan.getCollateralRatio() < self.context.params.CRLiquidation)

    def repay(self, loanId: int):
        loan = self.loans[loanId]
        assert loan.repaid == False, "Loan already repaid"
        assert loan.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=loan.getDebtCurrent(), dryRun=False), "Not enough cash"
        assert self.eth.transfer(creditorRealCollateral=loan.borrower.eth, amount=loan.amountCollateral, dryRun=False), "Not enough collateral"
        loan.repaid = True
        return True


@dataclass
class VariableLoan:
    pool: VariablePool
    borrower: User

    amountUSDCLentOut: float            # Ghost parameter, unnecessary but useful for debugging

    scaledAmountUSDCLentOut: float
    amountCollateral: float
    startTime: int
    repaid: bool = False

    def getDebtCurrent(self):
        return self.scaledAmountUSDCLentOut * self.pool.liquidityIndex

    def getCollateralRatio(self):
        return self.amountCollateral * self.context.price / self.getDebtCurrent()



# @dataclass
# class VariablePool:
#     context: Context
#     minCollateralRatio: float
#     cash: RealCollateral
#     eth: RealCollateral
#     activeLoans: Dict[int, VariableLoan] = field(default_factory=dict)
#     uidLoans: int = 0
#
#     def setLendingOB(self, ob):
#         self.ob = ob
#
#     # NOTE: Rate per time unit
#     def getRatePerUnitTime(self):
#         # TODO: Fix this
#         return 1 / 1 + np.exp(- self.cash.free)
#
#     # TODO: Finish implementing and fix this
#     def takeLoan(self, borrower: User, amountUSDC: float, amountETH: float, dryRun=False):
#         if  not self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC, dryRun=True):
#             print(f"No enough reserves amountUSDC={amountUSDC}, self.cash.free={self.cash.free}")
#             return False, 0
#         if not borrower.eth.lock(amount=amountETH, dryRun=True):
#             print(f"No enough reserves amountETH={amountETH}, borrower.eth.free={borrower.eth.free}")
#             return False, 0
#         if (amountUSDC * self.getRatePerUnitTime()) * self.minCollateralRatio > amountETH * self.context.price:
#             print(f"Collateral not enough amountUSDC={amountUSDC}, amountETH={amountETH}, self.context.price={self.context.price}")
#             return False, 0
#         if dryRun:
#             return True, 0
#         self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC)
#         borrower.eth.lock(amount=amountETH)
#         self.activeLoans[self.uidLoans] = VariableLoan(
#             context=self.context,
#             pool=self,
#             borrower=borrower,
#             amountUSDCLentOut=amountUSDC,
#             amountCollateral=amountETH,
#             startTime=self.context.time)
#         self.uidLoans += 1
#         return True, self.uidLoans-1
#
#     def repay(self, loanId: int):
#         loan = self.activeLoans[loanId]
#         if loan.repaid:
#             print(f"Loan already repaid loanId={loanId}")
#             return False
#         if not loan.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=loan.getDentCurrent(), dryRun=True):
#             print(f"Not enough cash to repay loanId={loanId}")
#             return False
#         if not loan.borrower.eth.unlock(amount=loan.amountCollateral, dryRun=True):
#             print(f"Not enough ETH to repay loanId={loanId}")
#             return False
#         loan.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=loan.getDentCurrent())
#         loan.borrower.eth.unlock(amount=loan.amountCollateral)
#         loan.repaid = True
#         return True

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



class LendingOBParams:
    # Liquidations
    collateralPercPremiumToLiquidator: float = 0.3
    collateralPercPremiumToBorrower: float = 0.1

@dataclass
class LendingOB:
    context: Context
    vp: VariablePool
    cash: RealCollateral
    eth: RealCollateral
    usersCash: Dict[User, float] = field(default_factory=dict)
    usersETHTotDeposited: Dict[User, float] = field(default_factory=dict)
    usersETHTotTotLockedByVP: Dict[User, float] = field(default_factory=dict)
    loanOffers: Dict[str, LoanOffer] = field(default_factory=dict)
    borrowOffers: Dict[int, BorrowOffer] = field(default_factory=dict)
    activeLoans: Dict[int, GenericLoan] = field(default_factory=dict)
    # uidLoanOffers: int = 0
    uidBorrowOffers: int = 0
    uidLoans: int = 0
    generalParams: Params = field(default_factory=Params)
    params: LendingOBParams = field(default_factory=LendingOBParams)

    liquidationProfitUSDC: float = 0
    liquidationProfitETH: float = 0

    def getUserLockedETH(self, user: User):
        if user.uid not in self.usersETHTotTotLockedByVP:
            return 0
        return self.usersETHTotTotLockedByVP[user.uid]

    def getUserFreeETH(self, user: User):
        if user.uid not in self.usersETHTotDeposited:
            return 0
        return self.usersETHTotDeposited[user.uid] - self.getUserLockedETH(user)

    def addUserETH(self, user: User, amount: float):
        self.usersETHTotDeposited[user.uid] = amount if user.uid not in self.usersETHTotDeposited else self.usersETHTotDeposited[user.uid] + amount
        assert self.usersETHTotDeposited[user.uid] >= 0, "This should never happen"

    def addUserCash(self, user: User, amount: float):
        self.usersCash[user.uid] = amount if user.uid not in self.usersCash else self.usersCash[user.uid] + amount
        assert self.usersCash[user.uid] >= 0, "This should never happen"

    def getUserCash(self, user: User):
        return self.usersCash[user.uid] if user.uid in self.usersCash else 0

    def lockUserETH(self, user: User, amount: float, dryRun=False):
        if amount > self.getUserFreeETH(user):
            print(f"WARNING: amount={amount} is too big, self.getUserFreeETH(user)={self.getUserFreeETH(user)}")
            return False
        if dryRun:
            return True
        self.usersETHTotTotLockedByVP[user.uid] = amount if user.uid not in self.usersETHTotTotLockedByVP else self.usersETHTotTotLockedByVP[user.uid] + amount
        assert self.usersETHTotTotLockedByVP[user.uid] >= 0, "This should never happen"
        return True

    def unlockUserETH(self, user: User, amount: float, dryRun=False):
        if amount > self.getUserLockedETH(user):
            print(f"WARNING: amount={amount} is too big, self.getUserLockedETH(user)={self.getUserLockedETH(user)}")
            return False
        if dryRun:
            return True
        self.usersETHTotTotLockedByVP[user.uid] -= amount
        assert self.usersETHTotTotLockedByVP[user.uid] >= 0, "This should never happen"
        return True

    def getUserVirtualCollateralPerDate(self, user: User, dueDate: int):
        loansIds = [loanId for loanId in self.activeLoans if
                    self.activeLoans[loanId].lender == user and
                    not self.activeLoans[loanId].repaid and
                    self.activeLoans[loanId].getDueDate() <= dueDate]
        return sum([self.activeLoans[loanId].getCredit() for loanId in loansIds])

    def getUserVirtualCollateralInRange(self, user: User, rangeTime):
        res = np.zeros(len(rangeTime))
        for i in range(len(rangeTime)):
            res[i] = self.getUserVirtualCollateralPerDate(user=user, dueDate=rangeTime[i])
        return pd.DataFrame(data=res)

    def getFreeVirtualCollateral(self, lender: User, dueDate: int):
        loansIds = [loanId for loanId in self.activeLoans if loanId.lender == lender and loanId.getDueDate() <= dueDate]
        return sum([self.activeLoans[loanId].getCredit() for loanId in loansIds])


    def _getFOLAssignedCollateral(self, fol: FOL):
        return self.getUserFreeETH(fol.borrower) * fol.FV / fol.borrower.totDebtCoveredByRealCollateral if fol.borrower.totDebtCoveredByRealCollateral != 0 else 0

    # NOTE: It computes the collateral assigned to the FOL
    def getFOLAssignedCollateral(self, loanId: int):
        loan = self.activeLoans[loanId]
        assert loan.isFOL(), "This should never happen"
        return self._getFOLAssignedCollateral(loan)
        # return self.getUserFreeETH(loan.borrower) * loan.FV / loan.borrower.totDebtCoveredByRealCollateral if loan.borrower.totDebtCoveredByRealCollateral != 0 else 0

    def getProRataAssignedCollateral(self, loanId: int):
        loan = self.activeLoans[loanId]
        fol = loan.getFOL()
        folCollateral = self._getFOLAssignedCollateral(fol=fol)
        return folCollateral * loan.getCredit() / fol.getDebt()


    def deposit(self, user: User, amount: float, isUSDC: bool):
        assert amount > 0, "Can't call deposit with non positive amount"
        if isUSDC:
            if not user.cash.transfer(creditorRealCollateral=self.cash, amount=amount,dryRun=True):
                return False, 0
            user.cash.transfer(creditorRealCollateral=self.cash, amount=amount)
            self.addUserCash(user=user, amount=amount)
        else:
            if not user.eth.transfer(creditorRealCollateral=self.eth, amount=amount,dryRun=True):
                return False, 0
            user.eth.transfer(creditorRealCollateral=self.eth, amount=amount)
            self.addUserETH(user=user, amount=amount)
        return True


    def withdraw(self, user: User, amount: float, isUSDC: bool):
        assert amount > 0, "Can't call withdraw with non positive amount"
        if isUSDC:
            if not self.cash.transfer(creditorRealCollateral=user.cash, amount=amount,dryRun=True):
                return False, 0
            self.cash.transfer(creditorRealCollateral=user.cash, amount=amount)
            self.addUserCash(user=user, amount=-amount)
        else:
            if not self.eth.transfer(creditorRealCollateral=user.eth, amount=amount,dryRun=True):
                return False, 0
            self.eth.transfer(creditorRealCollateral=user.eth, amount=amount)
            self.addUserETH(user=user, amount=-amount)
        return True

    def getBorrowerCollateralRatio(self, borrower: User, extraDebt=0):
        return self.getUserFreeETH(borrower) * self.context.price / (borrower.totDebtCoveredByRealCollateral + extraDebt) if borrower.totDebtCoveredByRealCollateral != 0 else np.inf

    def isBorrowerLiquidatable(self, borrower: User, extraDebt=0):
        return self.getBorrowerCollateralRatio(borrower, extraDebt=extraDebt) < self.generalParams.CRLiquidation

    def isLoanLiquidatable(self, loanId: int):
        loan = self.activeLoans[loanId]
        return self.isBorrowerLiquidatable(borrower=loan.borrower)

    def lendAsLimitOrder(self, offer: LoanOffer):
        self.loanOffers[offer.lender.uid] = offer
        # self.uidLoanOffers += 1

    def borrowAsLimitOrder(self, offer: BorrowOffer):
        self.borrowOffers[self.uidBorrowOffers] = offer
        self.uidBorrowOffers += 1

    def createFOL(self, lender: User, borrower: User, FV: float, dueDate: int):
        self.activeLoans[self.uidLoans] = FOL(context=self.context, lender=lender, borrower=borrower, FV=FV, DueDate=dueDate, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1

    def createSOL(self, fol: FOL, lender: User, borrower: User, FV: float):
        self.activeLoans[self.uidLoans] = SOL(context=self.context, fol=fol, lender=lender, borrower=borrower, FV=FV, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1


    def borrowerExit(self, loanId: int, borrowOfferId: int):
        offer = self.borrowOffers[borrowOfferId]
        fol = self.activeLoans[loanId]
        lender = fol.borrower
        assert fol.isFOL(), "This should never happen"
        dueDate = fol.getDueDate()
        if dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)
        FV = fol.FV
        amountIn = FV / r
        if amountIn > offer.maxAmount:
            print(f"Money is too much amountIn={amountIn}, offer.maxAmount={offer.maxAmount}")
            return False, 0
        if self.getUserCash(lender) < amountIn:
            print(f"Lender lender.uid={lender.uid} has not enough free cash to lend out self.usersCash[lender.uid]={self.usersCash[lender.uid]}, amountIn={amountIn}")
            return False, 0
        if self.isBorrowerLiquidatable(borrower=offer.borrower, extraDebt=FV):
            print(f"WARNING: Borrower is liquidatable")
            return False, 0

        temp = self._lendCash(lender=lender, borrower=offer.borrower, amount=amountIn)
        if not temp:
            print("borrowerExit() Transfer in FOL failed")
            return False, 0
        offer.borrower.totDebtCoveredByRealCollateral += FV
        fol.borrower.totDebtCoveredByRealCollateral -= FV
        assert fol.borrower.totDebtCoveredByRealCollateral >= 0, "This should never happen"
        fol.borrower = offer.borrower
        # self.createFOL(lender=lender, borrower=offer.borrower, FV=FV, dueDate=dueDate)
        offer.maxAmount -= amountIn
        assert offer.maxAmount >= 0, "This should never happen"
        return True, 0


    def lendAsMarketOrder(self, lender: User, borrowOfferId: int, dueDate: int, amount: float, exactAmountIn: bool = False):
        # TODO: Implement
        offer = self.borrowOffers[borrowOfferId]
        if dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        if amount > offer.maxAmount:
            print(f"Money is too mucch amount={amount}, offer.maxAmount={offer.maxAmount}")
            return False, 0
        if self.getUserCash(lender) < amount:
            print(f"Lender lender.uid={lender.uid} has not enough free cash to lend out self.usersCash[lender.uid]={self.usersCash[lender.uid]}, amount={amount}")
            return False, 0

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)
        FV = r * amount if exactAmountIn else amount
        amountIn = amount if exactAmountIn else amount / r

        if self.isBorrowerLiquidatable(borrower=offer.borrower, extraDebt=FV):
            print(f"WARNING: Borrower is liquidatable")
            return False, 0

        temp = self._lendCash(lender=lender, borrower=offer.borrower, amount=amountIn)
        if not temp:
            print("borrowAsMarketOrder() Transfer in FOL failed")
            return False
        offer.borrower.totDebtCoveredByRealCollateral += FV
        self.createFOL(lender=lender, borrower=offer.borrower, FV=FV, dueDate=dueDate)
        offer.maxAmount -= amount
        assert offer.maxAmount >= 0, "This should never happen"
        return True, 0


    def _lendCash(self, lender: User, borrower: User, amount: float):
        if self.getUserCash(lender) < amount:
            print(f"Lender has not enough free cash to lend out self.usersCash[lender.uid]={self.getUserCash(lender)}, amount={amount})")
            return False
        print(f"_lendCash() lender.uid={lender.uid}, borrower.uid={borrower.uid}, amount={amount}")
        temp = self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
        if not temp:
            print("_lendCash() Transfer failed")
            return False
        self.addUserCash(user=lender, amount=-amount)
        # self.usersCash[lender.uid] -= amount
        return True

    def claim(self, loanId: int, dryRun=False):
        loan = self.activeLoans[loanId]
        # NOTE: Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet
        # NOTE: The CLAIMED can't be claimed either because its credit has already been consumed entirely either by a previous claim or by exiting before
        if not loan.getState() == LoanStates.REPAID:
            print(f"WARNING: Loan is not claimable loanId={loanId}, state = {loan.getState()}")
            return False
        if not dryRun:
            self.addUserCash(user=loan.lender, amount=loan.getCredit())
            loan.amountFVExited = loan.FV
        return True

    # NOTEs
    # Check on the dueDate
    # - the dueDate is in the future
    # - the dueDate has to be the yield curve range
    # - the dueDate has to be after the virtual collateral loans dueDate (if any) otherwise that specific VC loan is skipped
    def borrowAsMarketOrder(self, borrower: User, lender: User, dueDate: int, amount: float, exactAmountIn: bool = False, virtualCollateralLoansIds: List[int] = []):
        offer = self.loanOffers[lender.uid]
        if dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        if dueDate > offer.maxDueDate:
            print(f"Due Date out of range dueDate={dueDate}, offer.maxDueDate={offer.maxDueDate}")
            return False, 0
        if amount > offer.maxAmount:
            print(f"Money is not enough amount={amount}, offer.maxAmount={offer.maxAmount}")
            return False, 0

        # NOTE: Replaced by the check below
        # if dueDate > offer.maxDueDate:
        #     print(f"Due Date out of range dueDate={dueDate}, offer.maxDueDate={offer.maxDueDate}")
        #     return False, 0

        if self.getUserCash(offer.lender) < amount:
            print(f"Lender offer.lender.uid={offer.lender.uid} has not enough free cash to lend out self.usersCash[offer.lender.uid]={self.getUserCash(offer.lender)}, amount={amount}")
            return False, 0

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)

        # NOTE: The `amountOutLeft` is going to be decreased as more and more SOLs are created
        amountOutLeft = amount if not exactAmountIn else amount / r
        # amountOutLeft = amount

        # TODO: Create SOLs
        # NOTE: Taking loan with VC does not decrease the borrower CR
        for loanId in virtualCollateralLoansIds:
            # Full amount borrowed
            if amountOutLeft == 0:
                break
            loan = self.activeLoans[loanId]
            if loan.lender != borrower:
                print(f"Warning: Skipping loanId={loanId} since it is not owned by borrower")
                continue

            # Deprecated as RANC related
            # dueDate = dueDate if dueDate is not None else loan.getDueDate()

            if dueDate < loan.getDueDate():
                print(f"Warning: Skipping loanId={loanId} since it is due before the offer dueDate")
                continue
            amountInLeft = r * amountOutLeft
            deltaAmountIn = min(amountInLeft, self.activeLoans[loanId].getCredit())
            deltaAmountOut = deltaAmountIn / r

            # No money transfer here, only future cashflow transfer
            self.createSOL(fol=loan.getFOL(), lender=offer.lender, borrower=borrower, FV=deltaAmountIn)
            temp = loan.lock(deltaAmountIn)
            if not temp:
                print("Lock failed")
                return False
            # NOTE: Transfer `deltaAmountOut` for each SOL created
            temp = self._lendCash(lender=offer.lender, borrower=borrower, amount=deltaAmountOut)
            if not temp:
                print("borrowAsMarketOrder() Transfer in SOLs failed")
                return False
            # offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=deltaAmountOut)
            offer.maxAmount -= deltaAmountOut
            amountInLeft -= deltaAmountIn
            amountOutLeft -= deltaAmountOut

        # TODO: Cover the remaining amount with real collateral
        # NOTE: Taking loan with RC decreases the borrower CR
        if amountOutLeft > 0:
            print(f"Final Check amountOutLeft = {amountOutLeft}")
            FV = r * amountOutLeft

            if self.isBorrowerLiquidatable(borrower=borrower, extraDebt=FV):
                print(f"WARNING: Borrower is liquidatable")
                return False, 0

            # NOTE: Checking Opening Collateral Ratio
            maxETHToLock = (FV / self.context.price) * self.generalParams.CROpening
            if not (self.getUserFreeETH(borrower) >= maxETHToLock):
            # if not borrower.eth.lock(amount=maxETHToLock):
                # TX Reverts
                print(f"WARNING: Real Collateral is not enough to take the loan")
                return False, 0
            # TODO: Lock ETH to cover that amount
            temp = self._lendCash(lender=offer.lender, borrower=borrower, amount=amountOutLeft)
            if not temp:
                print("borrowAsMarketOrder() Transfer in FOL failed")
                return False
            borrower.totDebtCoveredByRealCollateral += FV
            self.createFOL(lender=offer.lender, borrower=borrower, FV=FV, dueDate=dueDate)
            offer.maxAmount -= amountOutLeft
        return True, 0

    # def lenderExit(self, exitingLender: User, loanId: int, amount: float, lendersToExitTo: List[User], dueDate=None, dryRun=False):
    #     # NOTE: The exit is equivalent to a spot swap for exact amount in wheres
    #     # - the exiting lender is the taker
    #     # - the other lenders are the makers
    #     # The swap traverses the `offersIds` as they if they were ticks with liquidity in an orderbook
    #     loan = self.activeLoans[loanId]
    #     dueDate = dueDate if dueDate is not None else loan.getDueDate()
    #
    #     if not dueDate >= loan.getDueDate():
    #         print(f"Due Date need to be in the future dueDate={dueDate}, loan.getDueDate()={loan.getDueDate()}")
    #         return False, 0
    #
    #     # NOTE: A kind of access contorl that is not strictly required here but anyway let's use it
    #     if not loan.lender == exitingLender:
    #         print(f"Invalid lender")
    #         return False, 0
    #
    #     if not amount <= loan.getCredit():
    #         print(f"Amount too big amount={amount}, loan.getCredit()={loan.getCredit()}")
    #         return False, 0
    #
    #     amountInLeft = amount
    #     for lender in lendersToExitTo:
    #         # No more amountIn to swap
    #         if(amountInLeft == 0):
    #             break
    #
    #         offer = self.loanOffers[lender.uid]
    #         # No liquidity to take in this bin
    #         if(offer.maxAmount == 0):
    #             continue
    #
    #         temp, rate = offer.getRate(dueDate=dueDate)
    #         # NOTE: INvalid dueDate for this yield curve
    #         if not temp:
    #             return False, 0
    #
    #         r = (1 + rate)
    #
    #         # NOTE: Max credit this (exit to) lender is willing to accept
    #         maxDeltaAmountIn = r * offer.maxAmount
    #         deltaAmountIn = min(maxDeltaAmountIn, amountInLeft)
    #         deltaAmountOut = deltaAmountIn / r
    #
    #         # NOTE: Increases `amountFVExited` here
    #         temp = loan.lock(deltaAmountIn, dryRun=dryRun)
    #         if not temp:
    #             print("This should never happen")
    #             return False, 0
    #
    #         offer.lender.cash.transfer(creditorRealCollateral=exitingLender.cash, amount=deltaAmountOut, dryRun=dryRun)
    #
    #         if not dryRun:
    #             self.createSOL(fol=loan.getFOL(), lender=offer.lender, borrower=exitingLender, FV=deltaAmountIn)
    #             offer.maxAmount -= deltaAmountOut
    #         amountInLeft -= deltaAmountIn
    #     return True, amountInLeft



    def repay(self, loanId):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print("repay() Invalid loan type")
            return False
        if fol.repaid:
            print("repay() Nothing to repay")
            return False
        # NOTE: Atm we do not support partial repayment
        # if not amount >= fol.FV:
        #     print("Amount not sufficient")
        #     return False

        if not fol.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV, dryRun=True):
            print("repay() Not enough cash to repay")
            return False
        fol.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV)
        fol.borrower.totDebtCoveredByRealCollateral -= fol.FV
        assert fol.borrower.totDebtCoveredByRealCollateral >= 0, "This should never happen"
        fol.repaid = True
        return True

    # NOTE: The borrower compensate his debt in `loanToRepayId` with his credit in `loanToCompensateId`
    # NOTE: The compensation can not exceed both 1) the credit the lender of `loanToRepayId` to the borrower and 2) the credit the lender of `loanToCompensateId` there
    def compensate(self, loanToRepayId: int, loanToCompensateId: int, amount = None):
        loanToRepay = self.activeLoans[loanToRepayId]
        loanToCompensate = self.activeLoans[loanToCompensateId]
        if loanToCompensate.lender.uid != loanToRepay.borrower.uid:
            print("compensate() Invalid lender")
            return False
        if loanToRepay.repaid:
            print("compensate() Nothing to compensate")
            return False
        if loanToCompensate.repaid:
            print("compensate() Nothing to compensate")
            return False
        if loanToRepay.getDueDate() < loanToCompensate.getDueDate():
            print("compensate() Due date not compatible")
            return False

        temp = min(loanToRepay.getCredit(), loanToCompensate.getCredit())
        amountToCompensate = amount if amount is not None else temp
        if amountToCompensate > temp:
            print("compensate() Amount too big")
            return False
        # NOTE: Debt Reduction
        assert loanToRepay.reduceDebt(amountToCompensate), "This should never happen"
        # NOTE: Exiting the same amount
        assert loanToCompensate.lock(amountToCompensate), "This should never happen"
        # NOTE: Transfering the credit
        self.createSOL(fol=loanToCompensate.getFOL(), lender=loanToRepay.lender, borrower=loanToRepay.borrower, FV=amountToCompensate)
        return True


    def _moveToVariablePool(self, loanId: int, dryRun=True):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print(f"WARNING: Invalid loan type")
            return False
        # NOTE: In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed

        assignedCollateral = self.getFOLAssignedCollateral(loanId=loanId)
        # NOTE: Checking Opening Collateral Ratio
        openingCollateralRequested = (fol.FV / self.context.price) * self.generalParams.CROpening
        if not (assignedCollateral >= openingCollateralRequested):
            print(f"WARNING: Real Collateral is not enough to take the loan")
            return False, 0
        # TODO: Lock ETH to cover that amount
        if not self.lockUserETH(user=fol.borrower, amount=assignedCollateral, dryRun=dryRun):
            print("WARNING: Lock failed")
            return False

        if not self.vp.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV, dryRun=dryRun):
            print(f"WARNING: Not enough cash to transfer")
            return False

        if not dryRun:
            self.vp.activeLoans[self.vp.uidLoans] = VariableLoan(
                context=self.context,
                pool=self.vp,
                borrower=fol.borrower,
                amountUSDCLentOut=fol.FV,
                amountCollateral=assignedCollateral,
                startTime=self.context.time)
            self.vp.uidLoans += 1
        return True

    def moveToVariablePool(self, loanId: int, dryRun=True, withAssert=True):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print(f"WARNING: Invalid loan type")
            return False
        # NOTE: In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        assignedCollateral = self.getFOLAssignedCollateral(loanId=loanId)
        # NOTE: Checking Opening Collateral Ratio
        if not myAssert(self.vp.borrow(borrower=fol.borrower, amountLent=fol.getDebt(), amountCollateral=assignedCollateral, recipientOfCash=self, providerOfCollateral=self, withAssert=withAssert),
                        "It is not possible to convert the loan from fixed to variable", withAssert):
            return False
        fol.repaid = True
        return True

    def moveToVariablePool1(self, loanId: int, dryRun=True):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print(f"WARNING: Invalid loan type")
            return False
        if not fol.isOverdue():
            print(f"WARNING: Loan is not overdue")
            return False
        # NOTE: In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        assignedCollateral = self.getFOLAssignedCollateral(loanId=loanId)
        # NOTE: Checking Opening Collateral Ratio
        openingCollateralRequested = (fol.FV / self.context.price) * self.generalParams.CROpening
        if not (assignedCollateral >= openingCollateralRequested):
            print(f"WARNING: Real Collateral is not enough to take the loan")
            return False, 0
        # TODO: Lock ETH to cover that amount
        if not self.lockUserETH(user=fol.borrower, amount=assignedCollateral, dryRun=dryRun):
            print("WARNING: Lock failed")
            return False

        if not self.vp.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV, dryRun=dryRun):
            print(f"WARNING: Not enough cash to transfer")
            return False

        # NOTE: Safe to change the state of the loan
        fol.repaid = True
        if not dryRun:
            self.vp.activeLoans[self.vp.uidLoans] = VariableLoan(
                context=self.context,
                pool=self.vp,
                borrower=fol.borrower,
                amountUSDCLentOut=fol.FV,
                amountCollateral=assignedCollateral,
                startTime=self.context.time)
            self.vp.uidLoans += 1
        return True


    # def unlock(self, loanId: int, time: int, amount: float):
    #     loan = self.activeLoans[loanId]
    #     lender = loan.lender()
    #     lender.schedule.unlocked[time] += amount
    #     if not np.all(lender.schedule.RANC(nowTime=self.context.time) >= 0):
    #         # Revert TX
    #         lender.schedule.unlocked[time] -= amount
    #         assert False, f"Impossible to unlock loanId={loanId}, time={time}, amount={amount}"

    def _computeCollateralForDebt(self, amountUSDC: float) -> float:
        return amountUSDC / self.context.price


    def _liquidationSwap(self, liquidator: User, borrower: User, amountUSDC: float, amountETH: float, dryRun=False):
        # NOTE: Check the CR > 100% otherwise we prevent liquidation at loss since, considering it would be a net loss for the liquidator, it could be MEV like
        # The liquidator might have sent the transaction to the blockchain when it was profitable but it was included when profitability has gone
        if self.getUserFreeETH(borrower) < amountETH:
            print(f"WARNING: Not enough ETH to liquidate {borrower.uid} self.getUserFreeETH(borrower)={self.getUserFreeETH(borrower)}, amountETH={amountETH}")
            return False

        # NOTE: We send cash to the liquidator instead of just crediting cash since we want to favor flashloans
        if not liquidator.cash.transfer(creditorRealCollateral=self.cash, amount=amountUSDC, dryRun=dryRun):
            print(f"WARNING: Not enough cash to liquidate")
            return False

        assert self.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH, dryRun=dryRun), "This should never happen"

        if not dryRun:
            self.usersETHTotDeposited[borrower.uid] -= amountETH
            assert self.usersETHTotDeposited[borrower.uid] >= 0, "This should never happen"
        print("_liquidationSwap() Success")
        return True

    def selfLiquidate(self, lender: User, loanId: int, dryRun=False):
        loan = self.activeLoans[loanId]
        # if not self.isLoanLiquidatable(loanId=loanId):
        #     print(f"WARNING: Loan is not liquidatable")
        #     return False, 0
        # assignedCollateral = self.getFOLAssignedCollateral(loanId=loanId)
        assignedCollateral = self.getProRataAssignedCollateral(loanId=loanId)
        amountCollateralDebtCoverage = loan.getDebt(inCollateral=True)

        # NOTE: Atm we only allow self liquidation at loss but we can think of allowing it even when the loan is not underwater but eligible for liquidation
        if assignedCollateral >= amountCollateralDebtCoverage:
            # Liquidation at loss, we can prevent it for now since it can save the liquidator from MEV
            print(f"WARNING: Loan is not underwater so can't be self liquidated, assignedCollateral={assignedCollateral}, amountCollateralDebtCoverage={amountCollateralDebtCoverage}")
            return False, 0

        if not dryRun:
            # NOTE: Transfer ETH
            self.addUserETH(user=loan.getFOL().borrower, amount=-assignedCollateral)
            assert self.usersETHTotDeposited[loan.getFOL().borrower.uid] >= 0, "This should never happen"
            self.addUserETH(user=loan.lender, amount=assignedCollateral)

            # NOTE: Reduce debt process
            deltaFV = loan.getCredit()
            loan.FV -= deltaFV
            assert loan.getCredit() == 0, "This should never happen"
            loan.getFOL().borrower.totDebtCoveredByRealCollateral -= deltaFV

            if not loan.isFOL():
                fol = loan.getFOL()
                creditBefore = fol.getCredit()
                fol.FV -= deltaFV
                assert fol.FV >= 0, "This should never happen"
                fol.amountFVExited -= deltaFV
                assert fol.amountFVExited >= 0, "This should never happen"
                assert fol.getCredit() == creditBefore, "This should never happen"

        return True, 0


    # TODO: Finish Implementation
    def liquidateLoanWithReplacement(self, liquidator: User, loanId: int, borrowOfferId: int, withAssert=True):
        fol = self.activeLoans[loanId]
        FV = fol.FV
        dueDate = fol.getDueDate()
        if not myAssert(self.liquidateLoan(liquidator=liquidator, loanId=loanId), "Should be able to liquidate", withAssert):
            return False, 0

        offer = self.borrowOffers[borrowOfferId]
        if not myAssert(dueDate > self.context.time, f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}", withAssert):
            return False, 0

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)
        amountOut = FV / r

        if not myAssert(amountOut <= offer.maxAmount, "Should be able to liquidate", withAssert):
            return False, 0

        offer.maxAmount -= amountOut

        replacementProfit = FV - amountOut
        if not myAssert(replacementProfit >= 0, f"amountOut={amountOut}, FV={FV}, replacementProfit={replacementProfit}", withAssert):
            return False, 0

        if not myAssert(self.cash.transfer(creditorRealCollateral=offer.borrower.cash, amount=amountOut), "This should never happen", withAssert):
            return False, 0

        fol.borrower = offer.borrower
        fol.repaid = False
        fol.borrower.totDebtCoveredByRealCollateral += FV
        if not myAssert(not self.isLoanLiquidatable(loanId=loanId), f"The loanId={loanId} should not be liquidatable", withAssert):
            return False, 0
        print("LiquidateWithReplacement() Success")
        return True, replacementProfit


    def liquidateLoan(self, liquidator: User, loanId: int):
        # TODO: Finish implementing
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print("Only FOL can be liquidated")
            return False, 0
        if not self.isLoanLiquidatable(loanId=loanId):
            print(f"WARNING: Loan is not liquidatable")
            return False, 0
        assignedCollateral = self.getFOLAssignedCollateral(loanId=loanId)
        amountCollateralDebtCoverage = fol.getDebt(inCollateral=True)
        if assignedCollateral < amountCollateralDebtCoverage:
            # Liquidation at loss, we can prevent it for now since it can save the liquidator from MEV
            print(f"WARNING: Not enough collateral to sell, assignedCollateral={assignedCollateral}, amountCollateralDebtCoverage={amountCollateralDebtCoverage}")
            return False, 0

        collateralRemainder = assignedCollateral - amountCollateralDebtCoverage
        collatetalPercToProtocol = 1 - (self.params.collateralPercPremiumToLiquidator + self.params.collateralPercPremiumToBorrower)
        amountCollateralToProtocol = collateralRemainder * collatetalPercToProtocol
        self.liquidationProfitETH += amountCollateralToProtocol
        amountCollateralToLiquidator = collateralRemainder * self.params.collateralPercPremiumToLiquidator
        amountCollateralToBorrower = collateralRemainder * self.params.collateralPercPremiumToBorrower

        print(f"amountCollateralDebtCoverage + amountCollateralToLiquidator = {amountCollateralDebtCoverage + amountCollateralToLiquidator}")
        print(f"User free ETH = {self.getUserFreeETH(fol.borrower)}")

        # if not self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=fol.getDebt(),
        #                          amountETH=amountCollateralDebtCoverage + amountCollateralToLiquidator, dryRun=True):
        #     print(f"WARNING: Failing Liquidaiton")
        #     return False, 0

        # TODO: Account collateral to protocol somewhere maybe
        if not self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=fol.getDebt(),
                              amountETH=amountCollateralDebtCoverage + amountCollateralToLiquidator):
            return False, 0
        self.usersETHTotDeposited[fol.borrower.uid] += amountCollateralToBorrower - amountCollateralDebtCoverage
        self.addUserETH(user=liquidator, amount=amountCollateralToLiquidator)
        fol.borrower.totDebtCoveredByRealCollateral -= fol.getDebt()
        fol.repaid = True
        return True, amountCollateralDebtCoverage + amountCollateralToLiquidator




class Test:
    def __init__(self):
        self.params = Params()
    def setup(self):
        self.context = Context(
            params=self.params,
            price=100,
            time=0
        )
        self.bob = User(
                        uid="Bob",
                        context=self.context,
                        cash=RealCollateral(free=100, locked=0),
                        eth=RealCollateral(free=100, locked=0))
        self.alice = User(
            uid="Alice",
            context=self.context,
             cash=RealCollateral(free=100, locked=0),
             eth=RealCollateral(free=100, locked=0))

        self.james = User(
            uid="James",
            context=self.context,
             cash=RealCollateral(free=100, locked=0),
             eth=RealCollateral(free=100, locked=0))

        self.candy = User(
            uid="Candy",
            context=self.context,
                          cash=RealCollateral(free=100, locked=0),
                          eth=RealCollateral(free=1000, locked=0))

        self.liquidator = User(uid="Liquidator1", context=self.context, cash=RealCollateral(free=10000, locked=0), eth=RealCollateral(free=0, locked=0))

        self.vp = VariablePool(context=self.context, cash=RealCollateral(free=100000, locked=0), eth=RealCollateral(),  minCollateralRatio=self.params.CRLiquidation)
        self.ob = LendingOB(context=self.context, vp=self.vp, cash=RealCollateral(free=0, locked=0), eth=RealCollateral())
        self.vp.setLendingOB(ob=self.ob)


    def test1(self):
        # NOTE: Deposit USDC for lending
        self.ob.deposit(user=self.alice, amount=100, isUSDC=True)
        assert self.alice.cash.free == 0, f"alice.cash.free = {self.alice.cash.free}"
        assert self.ob.getUserCash(self.alice) == 100, f"userCash[self.alice.uid] = {self.ob.getUserCash(self.alice)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.alice,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(self.params.maxTime))
        ))

        # NOTE: Deposit ETH for borrowing
        self.ob.deposit(user=self.james, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.james, lender=self.alice, amount=100, dueDate=6)
        assert temp, "borrowAsMarketOrder failed"
        assert len(self.ob.activeLoans) > 0, f"len(ob.activeLoans) = {len(self.ob.activeLoans)}"
        loan = self.ob.activeLoans[0]
        assert loan.FV == 100 * (1 + 0.03), f"loan.FV = {loan.FV}, expected = {100 * (1 + 0.03)}"
        assert loan.getCredit() == loan.FV

        temp = self.ob.getUserVirtualCollateralInRange(user=self.alice, rangeTime=range(12))
        expected = np.array([0 if i < 6 else loan.FV for i in range(12)])
        assert temp.equals(pd.DataFrame(data=expected))
        temp.plot(title="Alice Virtual Collateral before borrowing with it")

        temp = self.ob.getUserVirtualCollateralInRange(user=self.james, rangeTime=range(12))
        expected = np.zeros(12)
        assert temp.equals(pd.DataFrame(data=expected))
        temp.plot(title="James Virtual Collateral")

        temp = self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert temp, "Should work"
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.02, timeBuckets=range(self.params.maxTime))
        ))

        # NOTE: Alice borrows form Bob using virtual collateral
        temp = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=100, dueDate=6, virtualCollateralLoansIds=[0])
        assert temp, "borrowAsMarketOrder failed"
        temp = self.ob.getUserVirtualCollateralInRange(user=self.alice, rangeTime=range(12))
        expected = np.array([0 if i < 6 else (self.ob.activeLoans[0].FV - self.ob.activeLoans[1].FV) for i in range(12)])
        assert temp.equals(pd.DataFrame(data=expected))
        temp.plot(title="Alice Virtual Collateral after borrowing with it")

        assert not self.ob.claim(loanId=0), "Should not be able to claim"

        # NOTE: James repays
        temp = self.ob.repay(loanId=0)
        assert temp, "repay failed"
        assert loan.repaid, "loan.repaid should be True"
        assert self.ob.claim(loanId=0), "Should be able to claim"
        assert not self.ob.claim(loanId=0), "Should not be able to claim anymore since it was claimed already"

    # Test offer creation, borrowing and trying to lend again

    def test3(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=2, isUSDC=False)
        self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=100, dueDate=6)
        assert self.ob.getBorrowerCollateralRatio(borrower=self.alice) >= self.params.CROpening, f"Alice Collateral Ratio self.ob.getBorrowerCollateralRatio(borrower=self.alice)={self.ob.getBorrowerCollateralRatio(borrower=self.alice)}, CROpening={self.params.CROpening}"
        assert not self.ob.isBorrowerLiquidatable(borrower=self.alice), f"Borrower should not be liquidatable"

        # assert self.alice.collateralRatio() == self.params.CROpening, f"Alice Collateral Ratio alice.collateralRatio()={self.alice.collateralRatio()}, CROpening={self.params.CROpening}"
        # assert not self.alice.isLiquidatable(), f"Borrower should not be liquidatable"
        print(f"alice.collateralRatio = {self.ob.getBorrowerCollateralRatio(borrower=self.alice)}")

        self.context.update(newTime=self.context.time + 1, newPrice=60)
        assert self.ob.isBorrowerLiquidatable(borrower=self.alice), "Borrower should be eligible"
        fol = self.ob.activeLoans[0]
        assert self.ob.isLoanLiquidatable(loanId=0), "Loan should be liquidatable"

        temp, _ = self.ob.liquidateLoan(liquidator=self.liquidator, loanId=0)
        assert temp, "Loan should be liquidated"


    def testBasicExit1(self, amountToExitPerc=0.1):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.candy, amount=100, isUSDC=True)
        assert self.candy.cash.free == 0, f"candy.cash.free = {self.candy.cash.free}"
        assert self.ob.getUserCash(self.candy) == 100, f"userCash[self.candy.uid] = {self.ob.getUserCash(self.candy)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.candy,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.05, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        dueDate = 6
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=50, dueDate=dueDate)
        assert temp, "borrowAsMarketOrder failed"

        assert len(self.ob.activeLoans) == 1, f"Checking num of loans before len(self.ob.activeLoans)={len(self.ob.activeLoans)}"
        assert self.ob.activeLoans[0].isFOL(), "The first loan has be FOL"

        fol = self.ob.activeLoans[0]

        amountToExit = fol.FV * amountToExitPerc

        # NOTE: Lender exiting using borrow as market order
        temp, amountInLeft = self.ob.borrowAsMarketOrder(borrower=self.bob, lender=self.candy, amount=amountToExit, exactAmountIn=True, dueDate=dueDate, virtualCollateralLoansIds=[0])
        # temp, amountInLeft = self.ob.lenderExit(exitingLender=self.bob, loanId=0, amount=amountToExit, lendersToExitTo=[self.candy])

        assert len(self.ob.activeLoans) == 2, "Checking num of loans after"
        assert not self.ob.activeLoans[1].isFOL(), "The second loan has be SOL"
        sol = self.ob.activeLoans[1]
        assert sol.FV == amountToExit, "Amount to Exit should be the same"
        assert amountInLeft == 0, f"Should be able to exit the full amount amountInLeft={amountInLeft}"


    def testBorrowWithExit1(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve(timeBuckets=[3,8], rates=[0.03, 0.03])
            # curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.james, amount=100, isUSDC=True)
        assert self.james.cash.free == 0, f"james.cash.free = {self.james.cash.free}"
        assert self.ob.getUserCash(self.james) == 100, f"userCash[self.james.uid] = {self.ob.getUserCash(self.james)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.james,
            maxAmount=100,
            maxDueDate=12,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.05, timeBuckets=range(12))
        ))


        # Alice Borrows using real collateral only so that Bob has some virtual collateral
        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=70, dueDate=5)
        assert temp, "Alice Borrow Market Order should work"

        assert self.ob.getUserCash(self.bob) == 30, f"Bob expected money after lending self.ob.usersCash[self.bob.uid]={self.ob.getUserCash(self.bob)}"
        assert len(self.ob.activeLoans) == 1, f"Bob loan is expected to be active"
        loan_Bob_Alice = self.ob.activeLoans[0]
        temp, rate = self.ob.loanOffers[self.bob.uid].getRate(dueDate=5)
        assert temp, "Bob Alice loan not successful"
        r1 = 1 + rate
        print(f"r1 = {r1}")
        assert loan_Bob_Alice.lender == self.bob, "Bob is lender"
        assert loan_Bob_Alice.borrower == self.alice, "Alice is lender"
        assert loan_Bob_Alice.FV == 70*r1, f"loan_Bob_Alice.FV={loan_Bob_Alice.FV}, expected={70*r1}"
        assert loan_Bob_Alice.getDueDate() == 5, f"loan_Bob_Alice.dueDate={loan_Bob_Alice.getDueDate()}, expected 5"

        assert self.bob.cash.free == 0, f"james.bob.free = {self.bob.cash.free}"
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.bob, lender=self.james, amount=35, dueDate=10, virtualCollateralLoansIds=[0])
        assert temp, "Bob borrowAsMarketOrderByExiting Market Order should work"

        assert self.bob.cash.free == 35, f"Bob expected money borrowing using the loan as virtual collateral self.bob.cash.free={self.bob.cash.free}"
        assert len(self.ob.activeLoans) == 2, f"Bob SOL is expected to be active"
        loan_James_Bob = self.ob.activeLoans[1]
        temp, rate = self.ob.loanOffers[self.james.uid].getRate(dueDate=loan_Bob_Alice.getDueDate())
        assert temp, "James Bob loan not successful"
        r2 = 1 + rate
        assert loan_James_Bob.lender == self.james, "James is lender"
        assert loan_James_Bob.borrower == self.bob, "Bob is lender"
        assert loan_James_Bob.FV == 35*r2, f"loan_James_Bob.FV={loan_James_Bob.FV}, expected={35*r2}"
        assert loan_James_Bob.getDueDate() == loan_Bob_Alice.getDueDate(), f"loan_James_Bob.dueDate={loan_James_Bob.getDueDate()}, expected is {loan_Bob_Alice.getDueDate()}"

        print(f"Done")

    def testLoanMove1(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve(timeBuckets=[3,8], rates=[0.03, 0.03])
            # curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        # Alice Borrows using real collateral only so that Bob has some virtual collateral
        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=70, dueDate=5)
        assert temp, "Alice Borrow Market Order should work"

        # Move forward the clock as the loan is overdue
        self.context.time = 6
        fol = self.ob.activeLoans[0]
        assert fol.isOverdue(), "Loan should be overdue"
        assert len(self.vp.loans) == 0, "No active VP Loan before"
        assert not fol.repaid, "Loan should not be repaid before moving to the variable pool"
        assert self.ob.getUserLockedETH(self.alice) == 0, f"alice.eth.locked={self.ob.getUserLockedETH(self.alice)}"
        temp = self.ob.moveToVariablePool(loanId=0, dryRun=False)
        assert temp, f"Move to variable pool"
        assert fol.repaid, "Loan should be repaid by moving into the variable pool"
        assert len(self.vp.loans) == 1, "New VP Loan Created"
        # TODO: Update check
        # assert self.ob.getUserLockedETH(self.alice) > 0, f"alice.eth.locked={self.ob.getUserLockedETH(self.alice)}"


    def testSL1(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=2, isUSDC=False)
        self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=100, dueDate=6)
        assert self.ob.getBorrowerCollateralRatio(borrower=self.alice) >= self.params.CROpening, f"Alice Collateral Ratio self.ob.getBorrowerCollateralRatio(borrower=self.alice)={self.ob.getBorrowerCollateralRatio(borrower=self.alice)}, CROpening={self.params.CROpening}"
        assert not self.ob.isBorrowerLiquidatable(borrower=self.alice), f"Borrower should not be liquidatable"

        # assert self.alice.collateralRatio() == self.params.CROpening, f"Alice Collateral Ratio alice.collateralRatio()={self.alice.collateralRatio()}, CROpening={self.params.CROpening}"
        # assert not self.alice.isLiquidatable(), f"Borrower should not be liquidatable"
        print(f"alice.collateralRatio = {self.ob.getBorrowerCollateralRatio(borrower=self.alice)}")

        self.context.update(newTime=self.context.time + 1, newPrice=30)
        assert self.ob.isBorrowerLiquidatable(borrower=self.alice), "Borrower should be eligible"
        fol = self.ob.activeLoans[0]
        assert self.ob.isLoanLiquidatable(loanId=0), "Loan should be liquidatable"



        loan = self.ob.activeLoans[0]
        assert loan.FV > 0, f"loan.FV={loan.FV}"
        assert self.ob.getUserFreeETH(self.bob) == 0, f"bob.eth.free={self.ob.getUserFreeETH(self.bob)}"
        temp, _ = self.ob.selfLiquidate(lender=self.bob, loanId=0)
        assert temp, "Loan should be self liquidated"
        assert self.ob.getUserFreeETH(self.bob) > 0, f"bob.eth.free={self.ob.getUserFreeETH(self.bob)}"
        assert loan.FV == 0, f"loan.FV={loan.FV}"

    def testLendAsLimitOrder1(self):
        self.ob.deposit(user=self.alice, amount=2, isUSDC=False)
        assert len(self.ob.borrowOffers) == 0, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"
        self.ob.borrowAsLimitOrder(offer=BorrowOffer(
            context=self.context,
            borrower=self.alice,
            maxAmount=100,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))
        assert len(self.ob.borrowOffers) == 1, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"

        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"

        assert len(self.ob.activeLoans) == 0, f"len(self.ob.activeLoans)={len(self.ob.activeLoans)}"
        temp, _ = self.ob.lendAsMarketOrder(lender=self.bob, borrowOfferId=0, amount=70, dueDate=5)
        assert temp, "Alice Borrow Market Order should work"
        assert len(self.ob.activeLoans) == 1, f"len(self.ob.activeLoans)={len(self.ob.activeLoans)}"



    def testBorrowerExit1(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve(timeBuckets=[3,8], rates=[0.03, 0.03])
            # curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))


        self.ob.deposit(user=self.candy, amount=2, isUSDC=False)
        assert len(self.ob.borrowOffers) == 0, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"
        self.ob.borrowAsLimitOrder(offer=BorrowOffer(
            context=self.context,
            borrower=self.candy,
            maxAmount=100,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))
        assert len(self.ob.borrowOffers) == 1, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"

        # Alice Borrows using real collateral only so that Bob has some virtual collateral
        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        self.alice.cash.free += 500
        self.ob.deposit(user=self.alice, amount=200, isUSDC=True)
        assert self.ob.getUserCash(self.alice) == 200, f"alice.cash.free={self.ob.getUserCash(self.alice)}"
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=70, dueDate=5)
        assert temp, "Alice Borrow Market Order should work"

        temp, _ = self.ob.borrowerExit(loanId=0, borrowOfferId=0)
        assert temp, "Borrower Exit should work"



    def testLiquidationWithReplacement(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=2, isUSDC=False)
        self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=100, dueDate=6)
        assert self.ob.getBorrowerCollateralRatio(borrower=self.alice) >= self.params.CROpening, f"Alice Collateral Ratio self.ob.getBorrowerCollateralRatio(borrower=self.alice)={self.ob.getBorrowerCollateralRatio(borrower=self.alice)}, CROpening={self.params.CROpening}"
        assert not self.ob.isBorrowerLiquidatable(borrower=self.alice), f"Borrower should not be liquidatable"

        # assert self.alice.collateralRatio() == self.params.CROpening, f"Alice Collateral Ratio alice.collateralRatio()={self.alice.collateralRatio()}, CROpening={self.params.CROpening}"
        # assert not self.alice.isLiquidatable(), f"Borrower should not be liquidatable"
        print(f"alice.collateralRatio = {self.ob.getBorrowerCollateralRatio(borrower=self.alice)}")

        self.ob.deposit(user=self.candy, amount=200, isUSDC=False)
        assert self.ob.getUserFreeETH(self.candy) == 200, f"candy.eth.free={self.ob.getUserFreeETH(self.candy)}"
        # assert len(self.ob.borrowOffers) == 0, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"
        self.ob.borrowAsLimitOrder(offer=BorrowOffer(
            context=self.context,
            borrower=self.candy,
            maxAmount=100,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))
        # assert len(self.ob.borrowOffers) == 1, f"len(self.ob.borrowOffers)={len(self.ob.borrowOffers)}"

        self.context.update(newTime=self.context.time + 1, newPrice=60)
        assert self.ob.isBorrowerLiquidatable(borrower=self.alice), "Borrower should be eligible"
        assert self.ob.isLoanLiquidatable(loanId=0), "Loan should be liquidatable"

        fol = self.ob.activeLoans[0]
        assert(fol.borrower.uid == self.alice.uid), "Alice should be the borrower"
        assert(self.alice.totDebtCoveredByRealCollateral == fol.getDebt()), "Alice should have all her debt covered by real collateral"
        assert(self.candy.totDebtCoveredByRealCollateral == 0), "Candy"
        assert not fol.repaid, "Loan should not be repaid before"
        temp1, temp2 = self.ob.liquidateLoanWithReplacement(liquidator=self.liquidator, loanId=0, borrowOfferId=0)
        print(f"New Borrower CR = {self.ob.getBorrowerCollateralRatio(borrower=self.candy)}")
        print(f"temp1={temp1}")
        print(f"temp2={temp2}")
        assert temp1, "Loan should be liquidated"
        assert(fol.borrower.uid == self.candy.uid), "Candy should be the borrower"
        assert(self.candy.totDebtCoveredByRealCollateral == fol.getDebt()), "Candy should have all her debt covered by real collateral"
        assert(self.alice.totDebtCoveredByRealCollateral == 0), "Alice"
        assert not fol.repaid, "Loan should not be repaid after"








    def testBasicCompensate1(self, amountToExitPerc=0.1):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.getUserCash(self.bob) == 100, f"userCash[self.bob.uid] = {self.ob.getUserCash(self.bob)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.candy, amount=100, isUSDC=True)
        assert self.candy.cash.free == 0, f"candy.cash.free = {self.candy.cash.free}"
        assert self.ob.getUserCash(self.candy) == 100, f"userCash[self.candy.uid] = {self.ob.getUserCash(self.candy)}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.candy,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.05, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        dueDate = 6
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, lender=self.bob, amount=50, dueDate=dueDate)
        assert temp, "borrowAsMarketOrder failed"

        assert len(self.ob.activeLoans) == 1, f"Checking num of loans before len(self.ob.activeLoans)={len(self.ob.activeLoans)}"
        assert self.ob.activeLoans[0].isFOL(), "The first loan has be FOL"

        fol = self.ob.activeLoans[0]

        amountToBorrow = fol.FV / 10

        self.ob.deposit(user=self.bob, amount=50, isUSDC=False)
        # NOTE: Lender exiting using borrow as market order
        bobDebtBefore = self.bob.totDebtCoveredByRealCollateral
        temp, amountInLeft = self.ob.borrowAsMarketOrder(borrower=self.bob, lender=self.candy, amount=amountToBorrow, dueDate=dueDate)
        assert temp, "borrowAsMarketOrder failed"
        # temp, amountInLeft = self.ob.lenderExit(exitingLender=self.bob, loanId=0, amount=amountToExit, lendersToExitTo=[self.candy])
        bobDebtAfter = self.bob.totDebtCoveredByRealCollateral
        assert bobDebtAfter > bobDebtBefore, f"bobDebtAfter - bobDebtBefore = {bobDebtAfter - bobDebtBefore}, expected = {amountToBorrow}"


        temp = self.ob.compensate(loanToRepayId=1, loanToCompensateId=0)
        assert temp, "Compensation should work"
        assert self.bob.totDebtCoveredByRealCollateral == bobDebtBefore, f"bob.totDebtCoveredByRealCollateral={self.bob.totDebtCoveredByRealCollateral}, expected={bobDebtBefore}"

        # NOTE: Bob is both borrower with Candy and lender with Alice, so he should be able to repay the loan with Candy by using the credit Alice loan.

        # assert len(self.ob.activeLoans) == 2, "Checking num of loans after"
        # assert not self.ob.activeLoans[1].isFOL(), "The second loan has be SOL"
        # sol = self.ob.activeLoans[1]
        # assert sol.FV == amountToExit, "Amount to Exit should be the same"
        # assert amountInLeft == 0, f"Should be able to exit the full amount amountInLeft={amountInLeft}"









