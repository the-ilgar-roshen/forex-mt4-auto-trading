//+------------------------------------------------------------------+
//|                                                        trade.mq5 |
//|                        Copyright 2021, programmer.alex.lightman. |
//|                     https://github.com/programmer.alex.lightman  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, programmer.alex.lightman."
#property link      "https://github.com/programmer.alex.lightman"
#property version   "1.00"

// Input Enumerators
enum LOTS_MODE {
    MULTIPLY, // Lots Multiplies at each next new position 
    ADD,      // Lots Adds-up at each next new position 
    SAME      // just as is
};

// Input Parameters
input double    TakeProfitByAmount        = 0.02;    // Take Profit at ...
input int       PositionsToOpen           = 2;       // how many positions to open
input double    FirstPositionLots         = 0.01;    // Lots of the First Position
input double    NextPositionOpenCriteria  = -0.2;    // Criteria [amount of USD] for Opening the Next Position
input double    NextPositionLotsPercentge = 2;       // means 2 times more lots for the next position
input LOTS_MODE NextPositionLotsMode      = ADD;     // ADD - means + 1*Lots at each next new position 
input int       MagicNumber               = 8234682; // set your Magic Number

// ENUMERATORS : POSITION 
enum ENUM_POSITION_SIDE     { BUY = 21, SELL = 22, NONE = 00 };
enum ENUM_POSITION_SELECTOR { SELECT_BY_TICKET_2 = 11, SELECT_BY_INDEX = 12 };

// test vars
int positionTicket;


//+------------------------------------------------------------------+
//|                       API ADAPTER ON MQL4                        |
//+------------------------------------------------------------------+
string   currentPositionSymbol      = 0;
ulong    currentPositionSide        = 0; // BUY/SELL
ulong    currentPositionTicket      = 0;
int      currentPositionMagicNumber = 0;
datetime currentPositionOpenTime    = 0;
double   currentPositionLots        = 0;
double   currentPositionProfit      = 0;
double   currentPositionPrice       = 0;
double   currentPositionSwap        = 0; // what they charge for overnight opened positions
double   currentPositionCommission  = 0;
double   currentPositionError       = 0;

int nextPositionOpenCriteriaUpdated = 0;
int positionsToOpenUpdated = 0;


// select position/order
bool selectPosition(int ticket_or_index, ENUM_POSITION_SELECTOR selector) {
    int select = 0;

    if (selector == SELECT_BY_TICKET_2) {
        select = SELECT_BY_TICKET;
    }
    else if (selector == SELECT_BY_INDEX) {
        select = SELECT_BY_POS;
    }

    // success code
    bool successeded = OrderSelect(ticket_or_index, select, MODE_TRADES);

    if (successeded) {
        currentPositionMagicNumber = OrderMagicNumber();
        currentPositionTicket      = OrderTicket();
        currentPositionSymbol      = OrderSymbol();
        currentPositionSide        = OrderType();
        currentPositionOpenTime    = OrderOpenTime();
        currentPositionSwap        = OrderSwap();
        currentPositionProfit      = OrderProfit();
        currentPositionLots        = OrderLots();
        currentPositionPrice       = OrderOpenPrice();
        currentPositionCommission  = OrderCommission();
    }

    return successeded;
}

// open position/order or send request for that etc.
// @return ticket|-1
int openPosition(ENUM_POSITION_SIDE operation_side, double price, double lots, int magicNumber) {
    int   ticket       = 0;
    int   operation_is = 0;
    color _color       = clrNONE;

    string   symbol          = getCurrentSymbol();
    int      priceDifference = 0;
    double   stoploss        = 0.00;
    double   takeprofit      = 0.00;
    string   comment         = (string)magicNumber; // NULL - nothing
    datetime expiration      = 0;                   // never

    // set order type properly
    if (operation_side == BUY) {
        operation_is = OP_BUY;
        _color = clrGreen;
    }
    else if (operation_side == SELL) {
        operation_is = OP_SELL;
        _color = clrRed;
    }
    else {
        Print("ERROR [FUNCTION openPosition]: no support for other opertaion other than BUY/SELL");
        return(0);
    }

    // send the request BUY/SELL
    ticket = OrderSend(symbol, operation_is, lots, price, priceDifference, stoploss, takeprofit, comment, magicNumber, expiration, _color);

    // LOG 
    if(ticket < 0) {
        currentPositionError = GetLastError();
        Print(" ERROR [REQUEST: OrderSend] ", currentPositionError);
    }
    else {
        Print("New Position Opened !");
    }
    
    return(ticket < 0);
}

// market position
int openPositionNow(ENUM_POSITION_SIDE operation_side, double lots, int magicNumber) {
    double price = 0.00;
    if (operation_side == BUY) {
        price = getCurrentBidPrice();
    }
    else if (operation_side == SELL) {
        price = getCurrentAskPrice();
    }
    else {
        Print("ERROR [FUNCTION openPositionNow] : allowed operations are only BUY/SELL");
        return(-1);
    }

    return openPosition(operation_side, price, lots, magicNumber);
}

// close the position 
bool closePositionNow(int ticket_or_index, ENUM_POSITION_SELECTOR selector) {
    int ticket = 0;
    if (selector == SELECT_BY_INDEX) {
        Print("RUN [FUNCTION closePositionNow] : SELECT_BY_INDEX ", ticket_or_index);
        selectPositionByIndex(ticket_or_index);
    }
    else if (selector == SELECT_BY_TICKET_2) {
        Print("RUN [FUNCTION closePositionNow] : SELECT_BY_TICKET_2", ticket_or_index);
        selectPositionByTicket(ticket_or_index);
    }
    else {
        Print("ERROR [FUNCTION closePositionNow] : selector SHOULD BE SELECT_BY_INDEX|SELECT_BY_TICKET_2");
        return(false);
    }

    double currentPrice = 0.00;
    color  arrowColor   = clrGreen; // clrNONE;
    int    slippage     = 2;        // this is about slipping from the market price or something like that

    if (getPositionSide(currentPositionSide) == BUY) {
        currentPrice = getCurrentBidPrice();
    }
    else if (getPositionSide(currentPositionSide) == SELL) {
        currentPrice = getCurrentAskPrice();
    }
    else {
        Print("ERROR [FUNCTION closePositionNow] : getPositionSide ShOULD BE BUY or SELL");
        return(false);
    }

    // close the order at the current price
    bool closed = OrderClose(ticket_or_index, currentPositionLots, currentPrice, slippage, arrowColor);

    // RETURN SUCCESS OR ELSE
    return(closed);
}

// close all opened positions
bool closeAllPositions() {
    bool error = false;
    for (int i = 0; i < getPositionsTotal() - 1; i++) {
        error = closePositionNow(i, SELECT_BY_INDEX);

        if (error) {
            Print("ERROR [FUNCTION closeAllPositions] : NOT ALL POSITIONS WERE CLOSED !");
            return(false);
        }
    }

    return(true);
}

// close all opened positions
bool closeAllPositionsByMagic(int magicNumber) {
    // error flag
    bool error = false;

    // loop through all positions
    for (int i = 0; i < getPositionsTotal(); i++) {
        // check if this position has the same 'magic number' as given via parameter 'magicNumber'
        if (currentPositionMagicNumber != magicNumber) {
            continue; // means, skip this one which does not match with 'magicNumber'
        }

        // try to close the selected position
        error = closePositionNow(i, SELECT_BY_INDEX);

        // if there is any error or if even one position had an error on closing then deprecate all
        if (error) {
            Print("ERROR [FUNCTION closeAllPositions] : NOT ALL POSITIONS WERE CLOSED !");
            return(false);
        }
    }

    // if everything is ok and all positions is closed properly without a single error
    return(true);
}

int selectLatestPosition() {
    return selectPositionByIndex( getPositionsTotal() - 1 );
}

bool selectPositionByIndex(int index) {
    return selectPosition(index, SELECT_BY_INDEX);
}

bool selectPositionByTicket(int ticket) {
    return selectPosition(ticket, SELECT_BY_TICKET_2);
}

int getPositionsTotal() {
    return OrdersTotal();
}

int getPositionsTotalByMagic(int magicNumber) {
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        selectPositionByIndex(i);
        if (currentPositionMagicNumber != magicNumber) {
            continue;
        }

        count++;
    }

    return count;
}


double getCurrentBidPrice() {
    // MarketInfo("EURUSD",MODE_BID)
    return Bid;
}

double getCurrentAskPrice() {
    return Ask;
}

string getCurrentSymbol() {
    return Symbol();
}

int getCurrentSpread() {
    return (int) MarketInfo( getCurrentSymbol(), MODE_SPREAD );
}

// NOTE: CHECK FOR BUGS AT i - 1 = getPositionsTotal() - 1
double getTotalProfit() {
    double totalProfit = 0.00;
    for (int i = 0; i < getPositionsTotal(); i++) {
        selectPositionByIndex(i);
        totalProfit += currentPositionProfit + currentPositionSwap - currentPositionCommission;
    }

    return totalProfit;
}

// count total profit from all 'magic' positions
double getTotalProfitByMagic(int magicNumber) {
    double totalProfit = 0.00;
    for (int i = 0; i < getPositionsTotal(); i++) {
        selectPositionByIndex(i);
        if (currentPositionMagicNumber != magicNumber) {
            continue;
        }
        totalProfit += currentPositionProfit + currentPositionSwap - currentPositionCommission;
    }

    return totalProfit;
}


ENUM_POSITION_SIDE getPositionSide(int side) {
    if (side == OP_BUY) {
        return (BUY);
    }
    else if (side == OP_SELL) {
        return (SELL);
    }
    else {
        Print("ERROR [getPositionSide] : ALLOWED ONLY BUY/SELL");
    }

    return(NONE);
}

string getPositionSideString(int side) {
    ENUM_POSITION_SIDE _side = getPositionSide(side);

    if (_side == BUY) {
        return ("BUY");
    }
    else if (_side == SELL) {
        return ("SELL");
    }
    
    return ("");
}

//+------------------------------------------------------------------+
//|                       Working - BRAIN                            |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                           RUNNERS                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit() {
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // estimate total/net profit
    double totalProfit = getTotalProfitByMagic(MagicNumber);
    // close all positions at Profit
    if (totalProfit >= TakeProfitByAmount) {
        // close all positions
        closeAllPositionsByMagic(MagicNumber);
    }

    // count all opened positions which has the magicNumber
    int totalPositions = getPositionsTotalByMagic(MagicNumber);

    // how many positions left to open
    int positionLeftToOpen = PositionsToOpen - totalPositions;

    // check for some weird cases
    if (positionLeftToOpen < 0) {
        Print("ERROR [FUNCTION OnTick] : INCORRECT positionLeftToOpen < 0");
        return;
    }

    // check whether or not and how to open positions
    if (positionLeftToOpen == 0) {
        // means all positions were filled/opened
    }
    // needs to open 'the First' position
    else if (totalPositions == 0) {
        // log
        Print("totalPositions: ", totalPositions);

        // send a request for the new [or the first] order
        openPositionNow(BUY, FirstPositionLots, MagicNumber);
        
        // set the profit criteria for the next position to be open
        nextPositionOpenCriteriaUpdated = NextPositionOpenCriteria;

        // set the default PositionsToOpen
        positionsToOpenUpdated = PositionsToOpen;

        // when there is not enough balance or so
        if (currentPositionError == ERR_NOT_ENOUGH_MONEY) {
            // ~change strategy
            positionsToOpenUpdated = totalPositions;
        }
    }
    // trailing positions - there is some positions left to open
    else if (totalPositions < positionsToOpenUpdated && totalProfit <= nextPositionOpenCriteriaUpdated) {
        // estimate Lots for the next [actually this one] position
        double lots = 0.00;

        // update the profit criteria for the next position to be open
        nextPositionOpenCriteriaUpdated = totalProfit + NextPositionOpenCriteria;

        // when needs to double the Size of Lots for each Next new position to open
        if (NextPositionLotsMode == MULTIPLY) {
            lots = MathPow(FirstPositionLots, (totalPositions + 1));
        }
        // add up by the Size given at 'FirstPositionLots' to the each new position
        else if (NextPositionLotsMode == ADD) {
            lots = FirstPositionLots * (totalPositions + 1);
        }
        // left as is
        else {
            lots = FirstPositionLots;
        }

        // open the position with that estimated 'lots'
        openPositionNow(BUY, lots, MagicNumber);
    }

}


//+------------------------------------------------------------------+
//|                Test - Testing Functionality                      |
//+------------------------------------------------------------------+

// test initialization
void test_start() {
    positionTicket = openPositionNow(BUY, 0.01, 1234);
    
    if (positionTicket > 0) {
        selectPositionByTicket(positionTicket);
    }
}
// test output/print or whatever
void test_output() {
    selectLatestPosition();
    
    Print(
        "currentPositionTicket: ", currentPositionTicket, "; ", 
        "currentPositionPrice: ", currentPositionPrice, "; ", 
        "currentPositionProfit: ", currentPositionProfit, "; ", 
        "getTotalProfit(): ", getTotalProfit(), "; ", 
        getPositionSideString(currentPositionSide)
    );
}

