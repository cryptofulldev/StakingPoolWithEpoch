# Overview of the Goals for v2:

- Allow on-the-go withdrawal and deposits for the pools using Epoch's
- Allow dyanmically changing size of pools/risk capacity
- Smart contracts for sale of insurance policies / direct onchain collection of premiums
- Allow investments in multiple currencies like ETH and UNO


## Changes in Premium Pool Structure:

- Allow premium collection in USDC, DAI, ETH, USDT and UNO. 
- @daksh / @gopesh please check which is the most popular currency used to collect premiums in and if the protocols keep their reserves in that same currency or not ?
- Explore if its possible to collect premiums in external tokens for distributor / agents like PolkaCover to sell policies and gain utility for their internal tokens ? 
- Explore possibility of onchain swap functionality to convert everthing to a stable currency (this has a good effect in bear / sideways trending market, but if the market is going up then we are loosing some high APR potential)
- Total Premiums Collected = 'z'. This value should be dynamic based on the assets inside the pool and their oraclized prices 



## Changes in Pool Structure:

- New param called Risk Tolerance = 'x'. Sum of Risk Tolerance for all pools should sum upto 100% (including UNO token pool). Defined as the percentage of the claims the users of a particular pool are going to take on. Should the claims amount be deducted from each pool after draining the premium pool or before draining the premium pool? The end result seems to be the same in both the cases but we need to clarify this from an implementation point of view - which is the better approach - @terry?

- Assume that there are n protocols in Pool and capital is distributed in PCT's as 'a1, a2, a3 .... an'
- Size of Pool = 'y'. It is dynamic and changes based on withdraws and deposits at the beginning of each epoch. Should we use oracles to denominate the size of pools in USD? (@terry please research on this) 

- Maximum APR of Pool = (x * z) / y . Fluctuates during a 1 week epoch cycle based on price of the tokens in the premium pool. To keep it static during a particular consider swapping all coins to stable currency in the premium pool. But is that the preferred option ?
- Pool Investments should be allowed in USDC, DAI, ETH, USDT and UNO.
- Parameter to control allowed inevstment in each currency - calculated relatively based on available investments in other currencies



## Changes in Protocol Structure:

- Maximum Capital Requirement Ratio (MCR) = 'm'. static value defined in constructor when adding a protocol. How much capital do we need to underwrite a particular amount of risk. 'm' is defined as total capital available for claims / total risk capacity taken based on premiums sold.

- Total Risk Capacity of a protocol = m * Sigma(y1 * a1). Here 'a1' is capital distribution PCT for protocol 1 in the particular pool of size 'y1'


  
## Addition of Insurance Sales Contract:

- Enable direct sales of policies.
- Should have parameter to set policy owner address
- Should allow integration for external parties like Polkacover at smart contract level using an Interface
- Should be a pause policy purchase functionality.
   There should be currentProtocolRiskCapacity = totalPremiumsSold/ premiumFactor 
   There should be maximumProtocolRiskCapacity = cohortCapitalPCTforProtocol * (total stakedCapitalInCohort * MCR) 

   cohortCapitalPCTforProtocol, MCR, Premium factor are static variables initialized when protocol is initiated in the factory



## Reward Calculation and Disbursement:

- Each cohort will be divided into epochs and duration of each epoch will be 1 week.
- Withdrawal requests will be proceeded in the corresponding epoch from when it was submitted. This will help streamline the rewards calculation after deducting claims amount.
- Deposits and Whithdrawals should only be tallied at the beginning of epochs to simplify calculations
- Amount invested by a user in a particular pool = p1
- Size of particular pool in the previous epoch = y1
- Risk tolerance PCT of particular pool = x1
- Total premiums collected in the previous epoch = Z
- Rewards for each user = (p / y1) * (x1) * Z

