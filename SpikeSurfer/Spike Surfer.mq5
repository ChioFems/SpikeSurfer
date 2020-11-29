//+------------------------------------------------------------------+
//|                                                 Spike Surfer.mq5 |
//|                                                      Raquel Fems |
//|                                            raquel.fems@gmail.com |
//|                                https://www.tradingwithraquel.com |
//+------------------------------------------------------------------+
#property copyright "Raquel Fems"
#property link      "https://www.tradingwithraquel.com"
#property version   "1.000"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
//+------------------------------------------------------------------+
//| Global object                                                    |
//+------------------------------------------------------------------+
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CDealInfo      m_deal;                       // deals object
COrderInfo     m_order;                      // pending orders object
CMoneyFixedMargin *m_money;
//+------------------------------------------------------------------+
//| Enum Lor or Risk                                                 |
//+------------------------------------------------------------------+
enum ENUM_LOT_OR_RISK
  {
   lot=0,   // Constant lot
   risk=1,  // Risk in percent for a deal
  };
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- input parameters
input string               ____1___               = "Trade Settings";
input ENUM_LOT_OR_RISK     IntLotOrRisk           = risk;     // Money management
input double               InpVolumeLotOrRisk     = 1.0;      // The value for "Money management"
input ushort               InpStopLoss            = 10;       // Stop Loss, in pips (1.00045-1.00055=1 pips)
input ushort               InpTakeProfit          = 200;      // Take Profit, in pips (1.00045-1.00055=1 pips)
input ushort               InpTrailingStop        = 5;        // Trailing Stop (min distance from Price to Stop Loss, in pips)
input ushort               InpTrailingStep        = 5;        // Trailing Step, in pips (1.00045-1.00055=1 pips)
input uchar                InpMaxPositions        = 1;        // Maximum positions ("1" - run on netting accounts, else hedging accounts)
input ulong                m_magic                = 35653;    // magic number
//--- inputs for main signal
input string               ____2___               = "Trend Indicator Settings";
input ENUM_TIMEFRAMES      InpTimeframe           = PERIOD_CURRENT; // MA and OHLC: Timeframe
input int                  ADX_Period             = 10;             // ADX Period
input double               Adx_Min                = 32.0;           // Minimum ADX Value
input int                  Inp_ma_period          = 12;             // MA: averaging period
input int                  Inp_ma_shift           = 3;              // MA: horizontal shift
input ENUM_MA_METHOD       Inp_ma_method          = MODE_EMA;       // MA: hsmoothing type
input ENUM_APPLIED_PRICE   Inp_applied_price      = PRICE_CLOSE;    // MA: type of price
//---
input string               ____3___               = "Scalper Indicator Settings";
input int                  Inp_jaw_period         = 13;             // period for the calculation of jaws
input int                  Inp_jaw_shift          = 8;              // horizontal shift of jaws
input int                  Inp_teeth_period       = 8;              // period for the calculation of teeth
input int                  Inp_teeth_shift        = 5;              // horizontal shift of teeth
input int                  Inp_lips_period        = 5;              // period for the calculation of lips
input int                  Inp_lips_shift         = 3;              // horizontal shift of lips
input ENUM_MA_METHOD       Inp_alli_ma_method     = MODE_EMA;       // type of smoothing
input ENUM_APPLIED_PRICE   Inp_alli_applied_price = PRICE_MEDIAN;   // type of price
//---
input double               InpMinimumIndent       = 0.001;          // Minimum indent AO from "0.0"
//--- other parameters
ulong  m_slippage=10;               // slippage

double ExtStopLoss=0.0;
double ExtTakeProfit=0.0;
double ExtTrailingStop=0.0;
double ExtTrailingStep=0.0;

int    handle_iAdx;                 // handle for our ADX indicator
double plsDI[],minDI[],adxVal[];    // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
int    handle_iMa;                  // handle for our Moving Average indicator
double maVal[];                     // Dynamic array to hold the values of Moving Average for each bars
double p_open;                      // Variable to store the open value of a bar
double p_close;                     // Variable to store the close value of a bar

int    handle_iAlligator;           // variable for storing the handle of the iAlligator indicator
int    handle_iAO;                  // variable for storing the handle of the iAO indicator

double m_adjusted_point;            // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTrailingStop!=0 && InpTrailingStep==0)
     {
      string err_text=(TerminalInfoString(TERMINAL_LANGUAGE)=="Swahili")?
                      "Treiling haiwezekani: parameta \"Trailing Step\" ni sifuri!":
                      "Trailing is not possible: parameter \"Trailing Step\" is zero!";
      //--- when testing, we will only output to the log about incorrect input parameters
      if(MQLInfoInteger(MQL_TESTER))
        {
         Print(__FUNCTION__,", ERROR: ",err_text);
         return(INIT_FAILED);
        }
      else // if the Expert Advisor is run on the chart, tell the user about the error
        {
         Alert(__FUNCTION__,", ERROR: ",err_text);
         return(INIT_PARAMETERS_INCORRECT);
        }
     }
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();
//---
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtStopLoss       = InpStopLoss        * m_adjusted_point;
   ExtTakeProfit     = InpTakeProfit      * m_adjusted_point;
   ExtTrailingStop   = InpTrailingStop    * m_adjusted_point;
   ExtTrailingStep   = InpTrailingStep    * m_adjusted_point;
//--- Trend indicators
//--- Get handle for ADX indicator
   handle_iAdx=iADX(NULL,PERIOD_M15,ADX_Period);
//--- Get the handle for Moving Average indicator
   handle_iMa=iMA(_Symbol,PERIOD_M15,Inp_ma_period,Inp_ma_shift,Inp_ma_method,Inp_applied_price);
//--- if the handle is not created or return Invalid Handle
   if(handle_iAdx<0 || handle_iMa<0)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(), EnumToString(PERIOD_M15), GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//--- Scalping indicators
//--- Create handle of the indicator iAlligator
   handle_iAlligator=iAlligator(m_symbol.Name(),Period(),Inp_jaw_period,Inp_jaw_shift,
                                Inp_teeth_period,Inp_teeth_shift,Inp_lips_period,Inp_lips_shift,
                                Inp_alli_ma_method,Inp_alli_applied_price);
//--- if the handle is not created
   if(handle_iAlligator==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iAlligator indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(), EnumToString(Period()), GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//--- create handle of the indicator iAO
   handle_iAO=iAO(m_symbol.Name(),Period());
//--- if the handle is not created
   if(handle_iAO==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iAO indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//---
   if(!LotsOrRisk(digits_adjust))
      return(INIT_FAILED);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if(m_money!=NULL)
      delete m_money;
//--- Release our indicator handles
   IndicatorRelease(handle_iAdx);
   IndicatorRelease(handle_iMa);
   IndicatorRelease(handle_iAlligator);
   IndicatorRelease(handle_iAO);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   Trailing();
//--- we work only at the time of the birth of new bar
   static datetime PrevBars=0;
   datetime time_0=iTime(m_symbol.Name(),Period(),0);
   if(time_0==PrevBars)
      return;
   PrevBars=time_0;

//--- Trend Logic
//--- Do we have enough bars to work with
   if(Bars(_Symbol,_Period)<60) // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

// We will use the static Old_Time variable to serve the bar time.
// At each OnTick execution we will check the current bar time with the saved one.
// If the bar time isn't equal to the saved time, it indicates that we have a new tick.

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

// copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied>0) // ok, the data has been copied successfully
     {
      if(Old_Time!=New_Time[0]) // if old time isn't equal to new bar time
        {
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING))
            Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         Old_Time=New_Time[0];            // saving bar time
        }
     }
   else
     {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
     }

//--- EA should only check for new trade if we have a new bar
   if(IsNewBar==false)
     {
      return;
     }

//--- Do we have enough bars to work with
   int Mybars=Bars(_Symbol,_Period);
   if(Mybars<60) // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

//--- Define some MQL5 Structures we will use for our trade
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);      // Initialization of mrequest structure
   /*
        Let's make sure our arrays values for the Rates, ADX Values and MA values
        is store serially similar to the timeseries array
   */
// the rates arrays
   ArraySetAsSeries(mrate,true);
// the ADX DI+values array
   ArraySetAsSeries(plsDI,true);
// the ADX DI-values array
   ArraySetAsSeries(minDI,true);
// the ADX values arrays
   ArraySetAsSeries(adxVal,true);
// the MA-8 values arrays
   ArraySetAsSeries(maVal,true);

//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

//--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(handle_iAdx,0,0,3,adxVal)<0 || CopyBuffer(handle_iAdx,1,0,3,plsDI)<0
      || CopyBuffer(handle_iAdx,2,0,3,minDI)<0)
     {
      Alert("Error copying ADX indicator Buffers - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }
   if(CopyBuffer(handle_iMa,0,0,3,maVal)<0)
     {
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
     }
//--- we have no errors, so continue
//--- Do we have positions opened already?
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   if(PositionSelect(_Symbol)==true) // we have an opened position
     {
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
        }
      else
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            Sell_opened=true; // It is a Sell
           }
     }

// Copy the bar open price for the current bar, that is Bar 0
   p_open=mrate[0].open;    // bar 0 open price
// Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
   p_close=mrate[1].close;  // bar 1 close price

//--- Scalping Indicators
//--- get indicators volume
   int start_pos=0,count=3, buffer=0;

   double jaw_array[];
   ArraySetAsSeries(jaw_array,true);
   if(!iGetArray(handle_iAlligator,GATORJAW_LINE,start_pos,count,jaw_array))
      return;

   double teeth_array[];
   ArraySetAsSeries(teeth_array,true);
   if(!iGetArray(handle_iAlligator,GATORTEETH_LINE,start_pos,count,teeth_array))
      return;

   double lips_array[];
   ArraySetAsSeries(lips_array,true);
   if(!iGetArray(handle_iAlligator,GATORLIPS_LINE,start_pos,count,lips_array))
      return;

   double ao_array[];
   ArraySetAsSeries(ao_array,true);
   if(!iGetArray(handle_iAO,buffer,start_pos,count,ao_array))
     {
      PrevBars=0;
      return;
     }
//---
   if(!RefreshRates())
     {
      PrevBars=0;
      return;
     }
   double freeze_level=m_symbol.FreezeLevel()*m_symbol.Point();
   if(freeze_level==0.0)
      freeze_level=(m_symbol.Ask()-m_symbol.Bid())*3.0;
   freeze_level*=1.1;

   double stop_level=m_symbol.StopsLevel()*m_symbol.Point();
   if(stop_level==0.0)
      stop_level=(m_symbol.Ask()-m_symbol.Bid())*3.0;
   stop_level*=1.1;

   if(freeze_level<=0.0 || stop_level<=0.0)
     {
      PrevBars=0;
      return;
     }
   /*
   1. Check for a long/Buy Setup : Pairs -> Crash 500 & Crash 1000
   MA is increasing upwards, current price open above it, open current price > previous close price,
   ADX > Adx min value, Adx is increasing upwards, +DI > -DI, AO change color and cross from below,
   AO is positive and change color and price is above alligator
   */

//--- Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = (_Symbol == "Crash 500 Index");             // Pairs allowed for ea
   bool Buy_Condition_2 = (_Symbol == "Crash 1000 Index");            // Pairs allowed for ea

   bool Buy_Condition_3 = (maVal[0]>maVal[1]) && (maVal[1]>maVal[2]); // MA Increasing upwards
   bool Buy_Condition_4 = (p_open > maVal[1]);                        // current price open above MA
   bool Buy_Condition_5 = (p_open >= p_close);                        // current price > previuos open price

   bool Buy_Condition_6 = (adxVal[0]>Adx_Min);                        // Current ADX value greater than minimum value
   bool Buy_Condition_7 = (adxVal[0]>adxVal[1]);                      // ADX is increasing in value
   bool Buy_Condition_8 = (plsDI[0]>minDI[0]);                        // +DI greater than -DI

// bool Buy_Condition_9  = ao_array[0]>ao_array[1] && ao_array[1]<ao_array[2] && ao_array[0]<-InpMinimumIndent; // AO buy below
   bool Buy_Condition_10 = ao_array[0]>ao_array[1] && ao_array[1]<ao_array[2] && ao_array[1]>InpMinimumIndent;  // AO buy above
   bool Buy_Condition_11 = ao_array[0]>ao_array[1] && ao_array[0]>InpMinimumIndent && ao_array[1]<-InpMinimumIndent; // AO buy cross over

// bool Buy_Condition_12   = lips_array[0]>=teeth_array[0] && lips_array[0]>=jaw_array[0] && lips_array[1]<teeth_array[2];
// bool Buy_Condition_13   = lips_array[1]>=jaw_array[1] && lips_array[2]<jaw_array[2];
// bool Buy_Condition_14   = lips_array[1]>=teeth_array[1] && lips_array[2]<teeth_array[2];
   bool Buy_Condition_15   = lips_array[0]>teeth_array[0] && teeth_array[0]>jaw_array[0];   // Current using this

//---
   /*
   2. Check for a short/Sell Setup : Pairs -> Boom 500 & Boom 1000
   MA is increasing upwards, current price open above it, open current price > previous close price,
   ADX > Adx min value, Adx is increasing upwards, +DI > -DI, AO change color and cross from below,
   AO is positive and change color and price is above alligator
   */
//--- Declare bool type variables to hold our Buy Conditions
   bool Sell_Condition_1 = (_Symbol == "Crash 500 Index");             // Pairs allowed for ea
   bool Sell_Condition_2 = (_Symbol == "Crash 1000 Index");            // Pairs allowed for ea

   bool Sell_Condition_3 = (maVal[0]>maVal[1]) && (maVal[1]>maVal[2]); // MA Increasing upwards
   bool Sell_Condition_4 = (p_open > maVal[1]);                        // current price open above MA
   bool Sell_Condition_5 = (p_open >= p_close);                        // current price > previuos open price

   bool Sell_Condition_6 = (adxVal[0]>Adx_Min);                        // Current ADX value greater than minimum value
   bool Sell_Condition_7 = (adxVal[0]>adxVal[1]);                      // ADX is increasing in value
   bool Sell_Condition_8 = (plsDI[0]>minDI[0]);                        // +DI greater than -DI

// bool Sell_Condition_9  = ao_array[0]>ao_array[1] && ao_array[1]<ao_array[2] && ao_array[0]<-InpMinimumIndent; // AO buy below
   bool Sell_Condition_10 = ao_array[0]>ao_array[1] && ao_array[1]<ao_array[2] && ao_array[1]>InpMinimumIndent;  // AO buy above
   bool Sell_Condition_11 = ao_array[0]>ao_array[1] && ao_array[0]>InpMinimumIndent && ao_array[1]<-InpMinimumIndent; // AO buy cross over

// bool Sell_Condition_12   = lips_array[0]>=teeth_array[0] && lips_array[0]>=jaw_array[0] && lips_array[1]<teeth_array[2];
// bool Sell_Condition_13   = lips_array[1]>=jaw_array[1] && lips_array[2]<jaw_array[2];
// bool Sell_Condition_14   = lips_array[1]>=teeth_array[1] && lips_array[2]<teeth_array[2];
   bool Sell_Condition_15   = lips_array[0]>teeth_array[0] && teeth_array[0]>jaw_array[0];   // Current using this

   bool alligator_sell  = lips_array[1]<=jaw_array[1] && lips_array[2]>jaw_array[2];
//---
   if(CalculateAllPositions()<InpMaxPositions)
     {
      if(Buy_Condition_1 || Buy_Condition_2)
        {
         if(Buy_Condition_8 && Buy_Condition_6)
           {
            if(Buy_Condition_3 && Buy_Condition_4 && Buy_Condition_5)
              {
               if((Buy_Condition_10 && Buy_Condition_15) || Buy_Condition_11)
                 {
                  double price=m_symbol.Ask();
                  double sl=(InpStopLoss==0)?0.0:price-ExtStopLoss;
                  double tp=(InpTakeProfit==0)?0.0:price+ExtTakeProfit;
                  if(((sl!=0 && ExtStopLoss>=stop_level) || sl==0.0) && ((tp!=0 && ExtTakeProfit>=stop_level) || tp==0.0))
                    {
                     OpenBuy(sl,tp);
                     Alert("A Buy order condition has been met!");
                     return;
                    }
                 }
              }
           }
        }
      if(ao_array[0]<ao_array[1] && ao_array[1]>ao_array[2] && ao_array[0]>InpMinimumIndent)
        {
         double price=m_symbol.Bid();
         double sl=(InpStopLoss==0)?0.0:price+ExtStopLoss;
         double tp=(InpTakeProfit==0)?0.0:price-ExtTakeProfit;
         if(((sl!=0 && ExtStopLoss>=stop_level) || sl==0.0) && ((tp!=0 && ExtTakeProfit>=stop_level) || tp==0.0))
           {
            // OpenSell(sl,tp);
            Alert("A Sell order condition has been met!");
            return;
           }
        }
     }
   else
     {
      //---
      MqlDateTime now;
      datetime current_time=TimeCurrent();
      TimeToStruct(current_time,now);
      if(PositionsTotal() > 0)
        {
         if(now.min > 2)
           {
            // Alert("Hello, 1 min passed");
            // if(ao_array[1]>0.0) // AO close order condition
            // if((lips_array[1]<=teeth_array[1] && lips_array[2]>teeth_array[2] && m_position.Profit()>=0.0)) // Alligator close order condition
              {
               ClosePositions(POSITION_TYPE_BUY);
               return;
              }
            // if(ao_array[1]<0.0) // AO close order condition
            // if(lips_array[1]>=teeth_array[1] && lips_array[2]<teeth_array[2] && m_position.Profit()>=0) // Alligator close order condition
            // {
            //  ClosePositions(POSITION_TYPE_SELL);
            // return;
            //}
           };
        };
     }
//---
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//---

  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the correctness of the position volume                     |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
// double min_volume=m_symbol.LotsMin();
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Swahili")
         error_description=StringFormat("Ujazo ni pungufu ya ujazo wa chini unaoruhusiwa SYMBOL_VOLUME_MIN=%.2f",min_volume);
      else
         error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }
//--- maximal allowed volume of trade operations
// double max_volume=m_symbol.LotsMax();
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Swahili")
         error_description=StringFormat("Ujazo ni zaidi ya ujazo wa juu unaoruhusiwa SYMBOL_VOLUME_MAX=%.2f",max_volume);
      else
         error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }
//--- get minimal step of volume changing
// double volume_step=m_symbol.LotsStep();
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Swahili")
         error_description=StringFormat("Ujazo sio maltipo ya stepu ya chini SYMBOL_VOLUME_STEP=%.2f, ближайший правильный объем %.2f",
                                        volume_step,ratio*volume_step);
      else
         error_description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                        volume_step,ratio*volume_step);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
//+------------------------------------------------------------------+
//| Lots or risk in percent for a deal from a free margin            |
//+------------------------------------------------------------------+
bool LotsOrRisk(const int digits_adjust)
  {
   if(IntLotOrRisk==lot)
     {
      //--- check the input parameter "Lots"
      string err_text="";
      if(!CheckVolumeValue(InpVolumeLotOrRisk,err_text))
        {
         Alert(__FUNCTION__,", ERROR: ",err_text);
         return(false);
        }
     }
   else
      if(IntLotOrRisk==risk)
        {
         if(m_money!=NULL)
            delete m_money;
         m_money=new CMoneyFixedMargin;
         if(m_money!=NULL)
           {
            if(!m_money.Init(GetPointer(m_symbol),Period(),m_symbol.Point()*digits_adjust))
               return(false);
            m_money.Percent(InpVolumeLotOrRisk);
           }
         else
           {
            Print(__FUNCTION__,", ERROR: Object CMoneyFixedMargin is NULL");
            return(false);
           }
        }
      else
        {
         return(false);
        }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Calculate all positions                                          |
//+------------------------------------------------------------------+
int CalculateAllPositions()
  {
   int total=0;

   for(int i=PositionsTotal()-1; i>=0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            total++;
//---
   return(total);
  }
//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==Symbol() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) // gets the position type
               m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+
//| Get value of buffers                                             |
//+------------------------------------------------------------------+
double iGetArray(const int handle,const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);
//--- reset error code
   ResetLastError();
//--- fill a part of the iBands array with values from the indicator buffer
   int copied=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
   return(result);
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double long_lot=0.0;
   if(IntLotOrRisk==risk)
     {
      long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);
      Print("sl=",DoubleToString(sl,m_symbol.Digits()),
            ", CheckOpenLong: ",DoubleToString(long_lot,2),
            ", Balance: ",    DoubleToString(m_account.Balance(),2),
            ", Equity: ",     DoubleToString(m_account.Equity(),2),
            ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
      if(long_lot==0.0)
        {
         Print(__FUNCTION__,", ERROR: method CheckOpenLong returned the value of \"0.0\"");
         return;
        }
     }
   else
      if(IntLotOrRisk==lot)
         long_lot=InpVolumeLotOrRisk;
      else
         return;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_BUY,long_lot,m_symbol.Ask());
   if(free_margin_check>0.0)
     {
      if(m_trade.Buy(long_lot,m_symbol.Name(),m_symbol.Ask(),sl,tp))
        {
         if(m_trade.ResultDeal()==0)
           {
            Print("#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
         else
           {
            Print("#2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         Print("#3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription());
         PrintResultTrade(m_trade,m_symbol);
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CAccountInfo::FreeMarginCheck returned the value ",DoubleToString(free_margin_check,2));
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_short_lot=0.0;
   if(IntLotOrRisk==risk)
     {
      check_open_short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);
      Print("sl=",DoubleToString(sl,m_symbol.Digits()),
            ", CheckOpenLong: ",DoubleToString(check_open_short_lot,2),
            ", Balance: ",    DoubleToString(m_account.Balance(),2),
            ", Equity: ",     DoubleToString(m_account.Equity(),2),
            ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
      if(check_open_short_lot==0.0)
        {
         Print(__FUNCTION__,", ERROR: method CheckOpenShort returned the value of \"0.0\"");
         return;
        }
     }
   else
      if(IntLotOrRisk==lot)
         check_open_short_lot=InpVolumeLotOrRisk;
      else
         return;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_SELL,check_open_short_lot,m_symbol.Bid());
   if(free_margin_check>0.0)
     {
      if(m_trade.Sell(check_open_short_lot,NULL,m_symbol.Bid(),sl,tp))
        {
         if(m_trade.ResultDeal()==0)
           {
            Print("#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
         else
           {
            Print("#2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         Print("#3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription());
         PrintResultTrade(m_trade,m_symbol);
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CAccountInfo::FreeMarginCheck returned the value ",DoubleToString(free_margin_check,2));
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Trailing                                                         |
//|   InpTrailingStop: min distance from price to Stop Loss          |
//+------------------------------------------------------------------+
void Trailing()
  {
   if(InpTrailingStop==0)
      return;
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep)
                  if(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep))
                    {
                     if(!m_trade.PositionModify(m_position.Ticket(),
                                                m_symbol.NormalizePrice(m_position.PriceCurrent()-ExtTrailingStop),
                                                m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                     PrintResultModify(m_trade,m_symbol,m_position);
                     continue;
                    }
              }
            else
              {
               if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtTrailingStop+ExtTrailingStep)
                  if((m_position.StopLoss()>(m_position.PriceCurrent()+(ExtTrailingStop+ExtTrailingStep))) ||
                     (m_position.StopLoss()==0))
                    {
                     if(!m_trade.PositionModify(m_position.Ticket(),
                                                m_symbol.NormalizePrice(m_position.PriceCurrent()+ExtTrailingStop),
                                                m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                     PrintResultModify(m_trade,m_symbol,m_position);
                    }
              }

           }
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultTrade(CTrade &trade,CSymbolInfo &symbol)
  {
   Print("File: ",__FILE__,", symbol: ",m_symbol.Name());
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: "+trade.ResultRetcodeDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("Order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultModify(CTrade &trade,CSymbolInfo &symbol,CPositionInfo &position)
  {
   Print("File: ",__FILE__,", symbol: ",m_symbol.Name());
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: "+trade.ResultRetcodeDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("Order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
   Print("Price of position opening: "+DoubleToString(position.PriceOpen(),symbol.Digits()));
   Print("Price of position's Stop Loss: "+DoubleToString(position.StopLoss(),symbol.Digits()));
   Print("Price of position's Take Profit: "+DoubleToString(position.TakeProfit(),symbol.Digits()));
   Print("Current price by position: "+DoubleToString(position.PriceCurrent(),symbol.Digits()));
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
