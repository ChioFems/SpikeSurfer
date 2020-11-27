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
input ulong                m_magic                = 356653;    // magic number
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