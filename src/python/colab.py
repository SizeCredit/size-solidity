
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

    # def __post_init__(self):
    #     self.schedule = Schedule(context=self.context)

    # def collateralRatio(self):
    #     print(f"totDebtCoveredByRealCollateral = {self.totDebtCoveredByRealCollateral}")
    #     res = np.inf if self.totDebtCoveredByRealCollateral == 0 else self.cash.locked + self.eth.locked * self.context.price / self.totDebtCoveredByRealCollateral
    #     print(f"self.cash.locked={self.cash.locked}, self.eth.locked={self.eth.locked}, self.context.price={self.context.price}, res = {res}")
    #     return res
    #
    # def isLiquidatable(self):
    #     return self.collateralRatio() < self.context.params.CRLiquidation


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
    amountFVExited: float

    # def __post_init__(self):
    #     self.amountFVExited = 0

    def isFOL(self):
        return not hasattr(self, "fol")

    # def isLiquidatable(self):
    #     return self.borrower.isLiquidatable()

    # NOTE: Lender Credit
    # NOTE: There is an asymmetry between the lender credit and the borrower debt, because of the exit mechanism
    def getCredit(self):
        return self.FV - self.amountFVExited

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

    # def getAssignedCollateral(self):
    #     return self.borrower.eth.locked * self.FV / self.borrower.totDebtCoveredByRealCollateral if self.borrower.totDebtCoveredByRealCollateral != 0 else 0

    def lock(self, amount: float):
        if amount > self.getCredit():
            print(f"WARNING: amount={amount} is too big, self.getCredit()={self.getCredit()}")
            return False
        self.amountFVExited += amount
        return True




@dataclass
class FOL(GenericLoan):
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
    usersETH: Dict[User, float] = field(default_factory=dict)
    loanOffers: Dict[int, LoanOffer] = field(default_factory=dict)
    borrowOffers: Dict[int, BorrowOffer] = field(default_factory=dict)
    activeLoans: Dict[int, GenericLoan] = field(default_factory=dict)
    uidLoanOffers: int = 0
    uidBorrowOffers: int = 0
    uidLoans: int = 0
    generalParams: Params = field(default_factory=Params)
    params: LendingOBParams = field(default_factory=LendingOBParams)

    def getAssignedCollateral(self, loanId: int):
        loan = self.activeLoans[loanId]
        return self.usersETH[loan.borrower.uid] * loan.FV / loan.borrower.totDebtCoveredByRealCollateral if loan.borrower.totDebtCoveredByRealCollateral != 0 else 0


    def deposit(self, user: User, amount: float, isUSDC: bool):
        if isUSDC:
            if not user.cash.transfer(creditorRealCollateral=self.cash, amount=amount,dryRun=True):
                return False, 0
            user.cash.transfer(creditorRealCollateral=self.cash, amount=amount)
            self.usersCash[user.uid] = amount if user.uid not in self.usersCash else self.usersCash[user.uid] + amount
        else:
            if not user.eth.transfer(creditorRealCollateral=self.eth, amount=amount,dryRun=True):
                return False, 0
            user.eth.transfer(creditorRealCollateral=self.eth, amount=amount)
            self.usersETH[user.uid] = amount if user.uid not in self.usersETH else self.usersETH[user.uid] + amount


    def withdraw(self, user: User, amount: float, isUSDC: bool):
        if isUSDC:
            if not self.cash.transfer(creditorRealCollateral=user.cash, amount=amount,dryRun=True):
                return False, 0
            self.cash.transfer(creditorRealCollateral=user.cash, amount=amount)
            self.usersCash[user.uid] -= amount
        else:
            if not self.eth.transfer(creditorRealCollateral=user.eth, amount=amount,dryRun=True):
                return False, 0
            self.eth.transfer(creditorRealCollateral=user.eth, amount=amount)
            self.usersETH[user.uid] -= amount

    def getBorrowerCollateralRatio(self, borrower: User):
        return self.usersETH[borrower.uid] * self.context.price / borrower.totDebtCoveredByRealCollateral if borrower.totDebtCoveredByRealCollateral != 0 else np.inf

    def isBorrowerLiquidatable(self, borrower: User):
        return self.getBorrowerCollateralRatio(borrower) < self.generalParams.CRLiquidation

    def isLoanLiquidatable(self, loanId: int):
        loan = self.activeLoans[loanId]
        return self.isBorrowerLiquidatable(borrower=loan.borrower)

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
        self.activeLoans[self.uidLoans] = SOL(context=self.context, fol=fol, lender=lender, borrower=borrower, FV=FV, amountFVExited=0)
        self.uidLoans += 1
        return self.uidLoans-1



    def lendAsMarketOrder(self, lender: User, borrowOfferId: int, dueDate: int, amount: float):
        # TODO: Implement
        offer = self.borrowOffers[borrowOfferId]
        if offer.dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        if amount > offer.maxAmount:
            print(f"Money is too mucch amount={amount}, offer.maxAmount={offer.maxAmount}")
            return False, 0
        if self.usersCash[lender.uid] < amount:
            print(f"Lender lender.uid={lender.uid} has not enough free cash to lend out self.usersCash[lender.uid]={self.usersCash[lender.uid]}, amount={amount}")
            return False, 0

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)


    def _lendCash(self, lender: User, borrower: User, amount: float):
        if self.usersCash[lender.uid] < amount:
            print(f"Lender has not enough free cash to lend out self.usersCash[lender.uid]={self.usersCash[lender.uid]}, amount={amount})")
            return False
        print(f"_lendCash() lender.uid={lender.uid}, borrower.uid={borrower.uid}, amount={amount}")
        temp = self.cash.transfer(creditorRealCollateral=borrower.cash, amount=amount)
        if not temp:
            print("_lendCash() Transfer failed")
            return False
        self.usersCash[lender.uid] -= amount
        return True


    # NOTEs
    # Check on the dueDate
    # - the dueDate is in the future
    # - the dueDate has to be the yield curve range
    # - the dueDate has to be after the virtual collateral loans dueDate (if any) otherwise that specific VC loan is skipped
    def borrowAsMarketOrder(self, borrower: User, offerId: int, dueDate: int, amount: float, virtualCollateralLoansIds: List[int] = []):
        offer = self.loanOffers[offerId]
        if dueDate <= self.context.time:
            print(f"Due Date need to be in the future dueDate={dueDate}, self.context.time={self.context.time}")
            return False, 0
        if amount > offer.maxAmount:
            print(f"Money is not enough amount={amount}, offer.maxAmount={offer.maxAmount}")
            return False, 0

        # NOTE: Replaced by the check below
        # if dueDate > offer.maxDueDate:
        #     print(f"Due Date out of range dueDate={dueDate}, offer.maxDueDate={offer.maxDueDate}")
        #     return False, 0

        if self.usersCash[offer.lender.uid] < amount:
            print(f"Lender offer.lender.uid={offer.lender.uid} has not enough free cash to lend out self.usersCash[offer.lender.uid]={self.usersCash[offer.lender.uid]}, amount={amount}")
            return False, 0

        temp, rate = offer.getRate(dueDate=dueDate)
        if not temp:
            print(f"WARNING: dueDate={dueDate} not available in the current offer")
            return False, 0
        r = (1 + rate)

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
                print("borrowAsMarketOrder() Transfer failed")
                return False
            # offer.lender.cash.transfer(creditorRealCollateral=borrower.cash, amount=deltaAmountOut)
            offer.maxAmount -= deltaAmountOut
            amountInLeft -= deltaAmountIn
            amountOutLeft -= deltaAmountOut

        # TODO: Cover the remaining amount with real collateral
        if amountOutLeft > 0:
            print(f"Final Check amountOutLeft = {amountOutLeft}")
            FV = r * amountOutLeft

            maxETHToLock = (FV / self.context.price) * self.generalParams.CROpening
            if not (borrower.uid in self.usersETH and self.usersETH[borrower.uid] >= maxETHToLock):
            # if not borrower.eth.lock(amount=maxETHToLock):
                # TX Reverts
                print(f"WARNING: Real Collateral is not enough to take the loan")
                return False, 0
            # TODO: Lock ETH to cover that amount
            borrower.totDebtCoveredByRealCollateral += FV
            self.createFOL(lender=offer.lender, borrower=borrower, FV=FV, dueDate=dueDate)
            self._lendCash(lender=offer.lender, borrower=borrower, amount=amountOutLeft)
        return True, 0

    def exit(self, exitingLender: User, loanId: int, amount: float, offersIds: List[int], dueDate=None):
        # NOTE: The exit is equivalent to a spot swap for exact amount in wheres
        # - the exiting lender is the taker
        # - the other lenders are the makers
        # The swap traverses the `offersIds` as they if they were ticks with liquidity in an orderbook
        loan = self.activeLoans[loanId]
        dueDate = dueDate if dueDate is not None else loan.getDueDate()
        # loan = self.activeFOLs[loanId] if isFOL else self.activeSOLs[loanId]
        assert loan.lender == exitingLender, "Invalid lender"
        assert amount <= loan.getCredit(), "Amount too big"
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


    def repay(self, loanId):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print("Invalid loan type")
            return False
        if fol.repaid:
            print("Nothing to repay")
            return False
        # NOTE: Atm we do not support partial repayment
        # if not amount >= fol.FV:
        #     print("Amount not sufficient")
        #     return False

        if not fol.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV, dryRun=True):
            print("Not enough cash to repay")
            return False
        fol.borrower.cash.transfer(creditorRealCollateral=self.cash, amount=fol.FV)
        fol.borrower.totDebtCoveredByRealCollateral -= fol.FV
        fol.repaid = True

        # # NOTE: For logging purpose onlys
        # excess = amount - fol.FVCoveredByRealCollateral
        #
        # # By default, all the future cashflow is considered locked
        # # This means to unlock it, the lender need to run some computation
        # fol.borrower.cash.free -= amount
        # fol.lender.cash.locked += fol.FVCoveredByRealCollateral
        # fol.borrower.totDebtCoveredByRealCollateral -= fol.FVCoveredByRealCollateral
        # fol.FVCoveredByRealCollateral = 0

    def _moveToVariablePool(self, loanId: int, dryRun=True):
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print(f"WARNING: Invalid loan type")
            return False
        collateralToTransfer = self.getAssignedCollateral(loanId=loanId)
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
        if self.usersETH[borrower.uid] < amountETH:
            print(f"WARNING: Not enough ETH to liquidate")
            return False
        if not dryRun:
            self.usersETH[borrower.uid] -= amountETH

        if not liquidator.cash.transfer(creditorRealCollateral=self.cash, amount=amountUSDC, dryRun=dryRun):
            print(f"WARNING: Not enough cash to liquidate")
            return False

        if not self.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH, dryRun=dryRun):
            print(f"WARNING: Not enough ETH to liquidate")
            return False

        # liquidator.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC, dryRun=dryRun)
        # borrower.cash.lock(amount=amountUSDC, dryRun=dryRun)
        # borrower.eth.unlock(amount=amountETH, dryRun=dryRun)
        # borrower.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH, dryRun=dryRun)


    # Deprecated
    # def liquidateBorrower(self, liquidator: User, borrower: User):
    #     assert borrower.isLiquidatable(), f"Borrower is not liquidatable"
    #     assert liquidator.cash.free >= borrower.totDebtCoveredByRealCollateral, f"Liquidator has not enough money liquidator.cash.free={liquidator.cash.free}, borrower.totDebtCoveredByRealCollateral={borrower.totDebtCoveredByRealCollateral}"
    #
    #     temp = borrower.cash.locked
    #     print(f"Before borrower.cash.locked = {borrower.cash.locked}")
    #
    #
    #     # NOTE: The `totDebtCoveredByRealCollateral` is already partially covered by the cash.locked so we need to transfer only the USDC for the part covered by ETH
    #     amountUSDC = borrower.totDebtCoveredByRealCollateral - borrower.cash.locked
    #
    #     targetAmountETH = self._computeCollateralForDebt(amountUSDC=amountUSDC)
    #     actualAmountETH = min(targetAmountETH, borrower.eth.locked)
    #     if(actualAmountETH < targetAmountETH):
    #         print(f"WARNING: Liquidation at loss, missing {targetAmountETH - actualAmountETH}")
    #     self._liquidationSwap(liquidator=liquidator, borrower=borrower, amountUSDC=amountUSDC, amountETH=actualAmountETH)
    #
    #     # liquidator.cash.transfer(creditorRealCollateral=borrower.cash, amount=amountUSDC)
    #     # borrower.cash.lock(amount=amountUSDC)
    #     #
    #     # print(f"After borrower.cash.locked = {borrower.cash.locked}")
    #     #
    #     # print(f"Delta locked = {borrower.cash.locked - temp}")
    #     #
    #     # borrower.eth.unlock(amount=amountETH)
    #     # borrower.eth.transfer(creditorRealCollateral=liquidator.eth, amount=amountETH)
    #     borrower.totDebtCoveredByRealCollateral = 0
    #     return actualAmountETH, targetAmountETH


    def liquidateLoan(self, liquidator: User, loanId: int):
        # TODO: Finish implementing
        fol = self.activeLoans[loanId]
        if not fol.isFOL():
            print("Only FOL can be liquidated")
            return False, 0
        if not self.isLoanLiquidatable(loanId=loanId):
            print(f"WARNING: Loan is not liquidatable")
            return False, 0
        assignedCollateral = self.getAssignedCollateral(loanId=loanId)
        amountCollateralDebtCoverage = fol.getDebt(inCollateral=True)
        if assignedCollateral < amountCollateralDebtCoverage:
            # Liquidation at loss, we can prevent it for now since it can save the liquidator from MEV
            print(f"WARNING: Not enough collateral to sell, assignedCollateral={assignedCollateral}, amountCollateralDebtCoverage={amountCollateralDebtCoverage}")
            return False, 0

        collateralRemainder = amountCollateralDebtCoverage - assignedCollateral
        collatetalPercToProtocol = 1 - (self.params.collateralPercPremiumToLiquidator + self.params.collateralPercPremiumToBorrower)
        amountCollateralToProtocol = collateralRemainder * collatetalPercToProtocol
        amountCollateralToLiquidator = collateralRemainder * self.params.collateralPercPremiumToLiquidator
        amountCollateralToBorrower = collateralRemainder * self.params.collateralPercPremiumToBorrower


        if self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=fol.getDebt(),
                                 amountETH=amountCollateralDebtCoverage + amountCollateralToLiquidator, dryRun=True):
            return False, 0

        self.usersETH[fol.borrower.uid] += amountCollateralToBorrower - amountCollateralDebtCoverage
        if liquidator.uid in self.usersETH:
            self.usersETH[liquidator.uid] += amountCollateralToLiquidator
        else:
            self.usersETH[liquidator.uid] = amountCollateralToLiquidator

        # TODO: Account collateral to protocol somewhere maybe
        self._liquidationSwap(liquidator=liquidator, borrower=fol.borrower, amountUSDC=fol.getDebt(),
                              amountETH=amountCollateralDebtCoverage + amountCollateralToLiquidator)
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
                          eth=RealCollateral())

        self.liquidator = User(uid="Liquidator1", context=self.context, cash=RealCollateral(free=10000, locked=0), eth=RealCollateral(free=0, locked=0))

        self.vp = VariablePool(context=self.context, cash=RealCollateral(free=100000, locked=0), eth=RealCollateral(),  minCollateralRatio=self.params.CRLiquidation)
        self.ob = LendingOB(context=self.context, vp=self.vp, cash=RealCollateral(free=0, locked=0), eth=RealCollateral())



    def test1(self):
        # NOTE: Deposit USDC for lending
        self.ob.deposit(user=self.alice, amount=100, isUSDC=True)
        assert self.alice.cash.free == 0, f"alice.cash.free = {self.alice.cash.free}"
        assert self.ob.usersCash[self.alice.uid] == 100, f"userCash[self.alice.uid] = {self.ob.usersCash[self.alice.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.alice,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(self.params.maxTime))
        ))

        # NOTE: Deposit ETH for borrowing
        self.ob.deposit(user=self.james, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.james, offerId=0, amount=100, dueDate=6)
        assert temp, "borrowAsMarketOrder failed"
        assert len(self.ob.activeLoans) > 0, f"len(ob.activeLoans) = {len(self.ob.activeLoans)}"
        loan = self.ob.activeLoans[0]
        assert loan.getCredit() == loan.FV

        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.usersCash[self.bob.uid] == 100, f"userCash[self.bob.uid] = {self.ob.usersCash[self.bob.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(self.params.maxTime))
        ))

        temp, _ = self.ob.repay(loanId=0)
        assert temp, "repay failed"
        assert loan.repaid, "loan.repaid should be True"

    # Test offer creation, borrowing and trying to lend again

    def test3(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.usersCash[self.bob.uid] == 100, f"userCash[self.bob.uid] = {self.ob.usersCash[self.bob.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=2, isUSDC=False)
        self.ob.borrowAsMarketOrder(borrower=self.alice, offerId=0, amount=100, dueDate=6)
        assert self.ob.getBorrowerCollateralRatio(borrower=self.alice) >= self.params.CROpening, f"Alice Collateral Ratio self.ob.getBorrowerCollateralRatio(borrower=self.alice)={self.ob.getBorrowerCollateralRatio(borrower=self.alice)}, CROpening={self.params.CROpening}"
        assert not self.ob.isBorrowerLiquidatable(borrower=self.alice), f"Borrower should not be liquidatable"

        # assert self.alice.collateralRatio() == self.params.CROpening, f"Alice Collateral Ratio alice.collateralRatio()={self.alice.collateralRatio()}, CROpening={self.params.CROpening}"
        # assert not self.alice.isLiquidatable(), f"Borrower should not be liquidatable"
        print(f"alice.collateralRatio = {self.ob.getBorrowerCollateralRatio(borrower=self.alice)}")

        # NOTE: Deprecated
        # self.ob.getBorrowerStatus(borrower=self.alice).plot()

        self.context.update(newTime=self.context.time + 1, newPrice=60)
        assert self.ob.isBorrowerLiquidatable(borrower=self.alice), "Borrower should be eligible"
        fol = self.ob.activeLoans[0]
        assert self.ob.isLoanLiquidatable(loanId=0), "Loan should be liquidatable"

        temp, _ = self.ob.liquidateLoan(liquidator=self.liquidator, loanId=0)
        assert temp, "Loan should be liquidated"

        # borrowerETHLockedBefore = self.alice.eth.locked
        # assert self.alice.isLiquidatable(), "Borrower should be eligible"
        # self.ob.getBorrowerStatus(borrower=self.alice).plot()

        # actualAmountETH, targetAmountETH = self.ob.liquidateBorrower(liquidator=self.liquidator, borrower=self.alice)
        #
        # assert not self.alice.isLiquidatable(), f"Alice should not be eligible for liquidation anymore after the liquidation event"
        # assert self.liquidator.eth.free == actualAmountETH, f"liquidator.eth.free = {self.liquidator.eth.free} expected = {actualAmountETH}"
        # assert self.alice.eth.locked == borrowerETHLockedBefore - actualAmountETH, f"alice.eth.locked={self.alice.eth.locked} expected {borrowerETHLockedBefore - actualAmountETH}"
        # assert self.liquidator.eth.locked == 0, "Liquidator ETH should be all free in this case"
        # ob.getBorrowerStatus(borrower=alice).plot()


    def testBasicExit1(self, amountToExitPerc=0.1):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.usersCash[self.bob.uid] == 100, f"userCash[self.bob.uid] = {self.ob.usersCash[self.bob.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.bob,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.03, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.candy, amount=100, isUSDC=True)
        assert self.candy.cash.free == 0, f"candy.cash.free = {self.candy.cash.free}"
        assert self.ob.usersCash[self.candy.uid] == 100, f"userCash[self.candy.uid] = {self.ob.usersCash[self.candy.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.candy,
            maxAmount=100,
            maxDueDate=10,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.05, timeBuckets=range(12))
        ))

        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, offerId=0, amount=50, dueDate=6)
        assert temp, "borrowAsMarketOrder failed"

        assert len(self.ob.activeLoans) == 1, f"Checking num of loans before len(self.ob.activeLoans)={len(self.ob.activeLoans)}"
        assert self.ob.activeLoans[0].isFOL(), "The first loan has be FOL"

        fol = self.ob.activeLoans[0]

        amountToExit = fol.FV * amountToExitPerc
        temp, amountInLeft = self.ob.exit(exitingLender=self.bob, loanId=0, amount=amountToExit, offersIds=[1])

        assert len(self.ob.activeLoans) == 2, "Checking num of loans after"
        assert not self.ob.activeLoans[1].isFOL(), "The second loan has be SOL"
        sol = self.ob.activeLoans[1]
        assert sol.FV == amountToExit, "Amount to Exit should be the same"
        assert amountInLeft == 0, f"Should be able to exit the full amount amountInLeft={amountInLeft}"


    def testBorrowWithExit1(self):
        self.ob.deposit(user=self.bob, amount=100, isUSDC=True)
        assert self.bob.cash.free == 0, f"bob.cash.free = {self.bob.cash.free}"
        assert self.ob.usersCash[self.bob.uid] == 100, f"userCash[self.bob.uid] = {self.ob.usersCash[self.bob.uid]}"
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
        assert self.ob.usersCash[self.james.uid] == 100, f"userCash[self.james.uid] = {self.ob.usersCash[self.james.uid]}"
        self.ob.lendAsLimitOrder(offer = LoanOffer(
            context=self.context,
            lender=self.james,
            maxAmount=100,
            maxDueDate=12,
            curveRelativeTime=YieldCurve.getFlatRate(rate=0.05, timeBuckets=range(12))
        ))


        # Alice Borrows using real collateral only so that Bob has some virtual collateral
        self.ob.deposit(user=self.alice, amount=50, isUSDC=False)
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.alice, offerId=0, amount=70, dueDate=5)
        assert temp, "Alice Borrow Market Order should work"

        assert self.ob.usersCash[self.bob.uid] == 30, f"Bob expected money after lending self.ob.usersCash[self.bob.uid]={self.ob.usersCash[self.bob.uid]}"
        assert len(self.ob.activeLoans) == 1, f"Bob loan is expected to be active"
        loan_Bob_Alice = self.ob.activeLoans[0]
        temp, rate = self.ob.loanOffers[0].getRate(dueDate=5)
        assert temp, "Bob Alice loan not successful"
        r1 = 1 + rate
        print(f"r1 = {r1}")
        assert loan_Bob_Alice.lender == self.bob, "Bob is lender"
        assert loan_Bob_Alice.borrower == self.alice, "Alice is lender"
        assert loan_Bob_Alice.FV == 70*r1, f"loan_Bob_Alice.FV={loan_Bob_Alice.FV}, expected={70*r1}"
        assert loan_Bob_Alice.getDueDate() == 5, f"loan_Bob_Alice.dueDate={loan_Bob_Alice.getDueDate()}, expected 5"

        assert self.bob.cash.free == 0, f"james.bob.free = {self.bob.cash.free}"
        temp, _ = self.ob.borrowAsMarketOrder(borrower=self.bob, offerId=1, amount=35, dueDate=10, virtualCollateralLoansIds=[0])
        assert temp, "Bob borrowAsMarketOrderByExiting Market Order should work"

        assert self.bob.cash.free == 35, f"Bob expected money borrowing using the loan as virtual collateral self.bob.cash.free={self.bob.cash.free}"
        assert len(self.ob.activeLoans) == 2, f"Bob SOL is expected to be active"
        loan_James_Bob = self.ob.activeLoans[1]
        temp, rate = self.ob.loanOffers[1].getRate(dueDate=loan_Bob_Alice.getDueDate())
        assert temp, "James Bob loan not successful"
        r2 = 1 + rate
        assert loan_James_Bob.lender == self.james, "James is lender"
        assert loan_James_Bob.borrower == self.bob, "Bob is lender"
        assert loan_James_Bob.FV == 35*r2, f"loan_James_Bob.FV={loan_James_Bob.FV}, expected={35*r2}"
        assert loan_James_Bob.getDueDate() == loan_Bob_Alice.getDueDate(), f"loan_James_Bob.dueDate={loan_James_Bob.getDueDate()}, expected is {loan_Bob_Alice.getDueDate()}"

        print(f"Done")





















