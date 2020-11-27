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
input ushort               InpTakeProfit          = 20;       // Take Profit, in pips (1.00045-1.00055=1 pips)
input ushort               InpTrailingStop        = 5;        // Trailing Stop (min distance from Price to Stop Loss, in pips)
input ushort               InpTrailingStep        = 5;        // Trailing Step, in pips (1.00045-1.00055=1 pips)
input uchar                InpMaxPositions        = 1;        // Maximum positions ("1" - run on netting accounts, else hedging accounts)
input ulong                m_magic                = 356653;   // magic number
//--- inputs for main signal
input string               ____2___               = "Trend Indicator Settings";
input ENUM_TIMEFRAMES      InpTimeframe           = PERIOD_CURRENT;     // MA and OHLC: Timeframe
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
input ENUM_MA_METHOD       Inp_alli_ma_method     = MODE_EMA;      // type of smoothing
input ENUM_APPLIED_PRICE   Inp_alli_applied_price = PRICE_MEDIAN;   // type of price
//---
input double               InpMinimumIndent       = 0.001;          // Minimum indent AO from "0.0"
//--- other parameters
ulong  m_slippage=10;               // slippage
//---
double ExtStopLoss=0.0;
double ExtTakeProfit=0.0;
double ExtTrailingStop=0.0;
double ExtTrailingStep=0.0;
//--- indicators
int    handle_iAdx;                 // handle for our ADX indicator
double plsDI[],minDI[],adxVal[];    // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
int    handle_iMa;                  // handle for our Moving Average indicator
double maVal[];                     // Dynamic array to hold the values of Moving Average for each bars
double p_open;                      // Variable to store the open value of a bar
double p_close;                     // Variable to store the close value of a bar
//---
int    handle_iAlligator;           // variable for storing the handle of the iAlligator indicator
int    handle_iAO;                  // variable for storing the handle of the iAO indicator
//---
double m_adjusted_point;            // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
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