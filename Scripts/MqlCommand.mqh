//+------------------------------------------------------------------+
//| Module: MqlCommand.mqh                                           |
//| This file is part of the mt4-server project:                     |
//|     https://github.com/dingmaotu/mt4-server                      |
//|                                                                  |
//| Copyright 2017 Li Ding <dingmaotu@hotmail.com>                   |
//|                                                                  |
//| Licensed under the Apache License, Version 2.0 (the "License");  |
//| you may not use this file except in compliance with the License. |
//| You may obtain a copy of the License at                          |
//|                                                                  |
//|     http://www.apache.org/licenses/LICENSE-2.0                   |
//|                                                                  |
//| Unless required by applicable law or agreed to in writing,       |
//| software distributed under the License is distributed on an      |
//| "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,     |
//| either express or implied.                                       |
//| See the License for the specific language governing permissions  |
//| and limitations under the License.                               |
//+------------------------------------------------------------------+
#property strict
#include <Mql/Trade/FxSymbol.mqh>
#include <Mql/Trade/OrderPool.mqh>
#include <Mql/Trade/Account.mqh>
#include <Mql/Trade/Order.mqh>
#include <Mql/Format/Resp.mqh>

int ParseOrderType(const string& direction, const string& type)
{
   string directionUpper = direction;
   string typeUpper = type;
   
   if(!StringToUpper(directionUpper) || !StringToUpper(typeUpper))
      return -1;
   
   if (directionUpper=="BUY")
   {
      if (typeUpper=="MARKET")
      {
         return OP_BUY;
      }
      else if (typeUpper=="STOP")
      {
         return OP_BUYSTOP;
      }
      else if (typeUpper=="LIMIT")
      {
         return OP_BUYLIMIT;
      }
   }
   else if (directionUpper=="SELL")
   {
      if (typeUpper=="MARKET")
      {
         return OP_SELL;
      }
      else if (typeUpper=="STOP")
      {
         return OP_SELLSTOP;
      }
      else if (typeUpper=="LIMIT")
      {
         return OP_SELLLIMIT;
      }
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Wraps a specific MQL command                                     |
//+------------------------------------------------------------------+
interface MqlCommand
  {
   RespValue        *call(const RespArray &command);
  };
//+------------------------------------------------------------------+
//| Get all orders in the Trade Pool                                 |
//| Syntax: ORDERS                                                   |
//| Results:                                                         |
//|   Success: Array of orders in string format                      |
//|   Success: Nil if no orders                                      |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class OrdersCommand: public MqlCommand
  {
private:
   TradingPool       m_pool;
public:
   RespValue        *call(const RespArray &command)
     {
      int total=m_pool.total();
      if(total==0) return RespNil::getInstance();
      RespArray *res=new RespArray(total);
      for (int i=0; i<total;i++)
        {
         if(m_pool.select(i))
           {
            Order o;
            res.set(i,new RespString(o.toString()));
           }
         else
           {
            res.set(i,RespNil::getInstance());
           }
        }
      return res;
     }
	};

//+------------------------------------------------------------------+
//| Give trade stats for account, in predefined output format.
//| Syntax: STATS Format
//| Valid formats are tab, csv and sh. The latter format should give
//| values that can be evaluated as shell variables, or used with
//| another, compatible scripting engine.
//+------------------------------------------------------------------+
class StatsCommand: public MqlCommand
{
	public:
		RespValue        *call(const RespArray &command)
		{
		  if (command.size() > 2) {
		    return new RespError("Unexpected arguments for STATS");
      }
		  string output_format = "tab";
		  if (command.size() == 2) {
        output_format = dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      }
		  StringToUpper(output_format);

      RespArray *res;
		  if (output_format == "TAB") {
        res = new RespArray(2);
        res.set(0,new RespString("Balance\tCredit\tProfit\tEquity\tMargin\tFree"));
        res.set(1,new RespString(StringFormat("%s\t%s\t%s\t%s\t%s\t%s",
              DoubleToStr(AccountBalance(), 2),
              DoubleToStr(AccountCredit(), 2),
              DoubleToStr(AccountProfit(), 2),
              DoubleToStr(AccountEquity(), 2),
              DoubleToStr(AccountMargin(), 2),
              DoubleToStr(AccountFreeMargin(), 2)
              )));

      } else if (output_format == "CSV") {
        res = new RespArray(2);
        res.set(0,new RespString("# Balance,Credit,Profit,Equity,Margin,Free"));
        res.set(1,new RespString(StringFormat("%s,%s,%s,%s,%s,%s",
              DoubleToStr(AccountBalance(), 2),
              DoubleToStr(AccountCredit(), 2),
              DoubleToStr(AccountProfit(), 2),
              DoubleToStr(AccountEquity(), 2),
              DoubleToStr(AccountMargin(), 2),
              DoubleToStr(AccountFreeMargin(), 2)
              )));

      } else if (output_format == "SH") {
        res = new RespArray(1);
        res.set(0,new RespString(StringFormat(
                  "balance=%s credit=%s profit=%s equity=%s margin=%s margin_free=%s",
              DoubleToStr(AccountBalance(), 2),
              DoubleToStr(AccountCredit(), 2),
              DoubleToStr(AccountProfit(), 2),
              DoubleToStr(AccountEquity(), 2),
              DoubleToStr(AccountMargin(), 2),
              DoubleToStr(AccountFreeMargin(), 2)
              )));

      } else {
        return new RespError("No such format");
      }
			return res;
    }
  };

class InfoCommand: public MqlCommand
  {
public:
  RespValue        *call(const RespArray &command)
    {
		  if (command.size() > 2) {
		    return new RespError("Unexpected arguments for INFO");
      }
		  string output_format = "tab";
		  if (command.size() == 2) {
        output_format = dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      }
		  StringToUpper(output_format);

      ENUM_ACCOUNT_STOPOUT_MODE stop_out_mode=(ENUM_ACCOUNT_STOPOUT_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
	 	  ENUM_ACCOUNT_TRADE_MODE account_type=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
	 	  string trade_mode;
	 	  switch(account_type) {
	 	 	 case  ACCOUNT_TRADE_MODE_DEMO:    trade_mode = "demo"; break;
	 	 	 case  ACCOUNT_TRADE_MODE_CONTEST: trade_mode = "contest"; break;
	 	 	 default:                          trade_mode = "real"; break;
	 	  }

      RespArray *res;
		  if (output_format == "TAB") {
        res = new RespArray(2);

        res.set(0,new RespString("Account\tCompany\tServer\tCurrency\tTrade-Mode\tMargin-So-Call\tMargin-So-So\tStopout-Mode"));
        res.set(1,new RespString(StringFormat("%i\t%s\t%s\t%s\t%s\t%s\t%s\t%s",
           AccountInfoInteger(ACCOUNT_LOGIN),
           AccountInfoString(ACCOUNT_COMPANY),
           //AccountInfoString(ACCOUNT_NAME),
           AccountInfoString(ACCOUNT_SERVER),
           AccountInfoString(ACCOUNT_CURRENCY),
           trade_mode,
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL)),
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO)),
           (stop_out_mode==ACCOUNT_STOPOUT_MODE_PERCENT)?"percentage":"money"
         )));

      } else if (output_format == "CSV") {
        res = new RespArray(2);

        res.set(0,new RespString("# Account,Company,Server,Currency,Trade-Mode,Margin-So-Call,Margin-So-So,Stopout-Mode"));
        res.set(1,new RespString(StringFormat("%i,%s,%s,%s,%s,%s,%s,%s",
           AccountInfoInteger(ACCOUNT_LOGIN),
           AccountInfoString(ACCOUNT_COMPANY),
           //AccountInfoString(ACCOUNT_NAME),
           AccountInfoString(ACCOUNT_SERVER),
           AccountInfoString(ACCOUNT_CURRENCY),
           trade_mode,
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL)),
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO)),
           (stop_out_mode==ACCOUNT_STOPOUT_MODE_PERCENT)?"percentage":"money"
         )));

      } else if (output_format == "SH") {
        res = new RespArray(1);

        res.set(0,new RespString(StringFormat("account=%i company=\"%s\" server=\"%s\" currency='%s' trade_mode='%s' margin_so_call=%s margin_so_so=%s stopout_mode=%s",
           AccountInfoInteger(ACCOUNT_LOGIN),
           AccountInfoString(ACCOUNT_COMPANY),
           //AccountInfoString(ACCOUNT_NAME),
           AccountInfoString(ACCOUNT_SERVER),
           AccountInfoString(ACCOUNT_CURRENCY),
           trade_mode,
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL)),
           DoubleToStr(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO)),
           (stop_out_mode==ACCOUNT_STOPOUT_MODE_PERCENT)?"percentage":"money"
         )));

      } else {
        return new RespError("No such format");
      }
      return res;
    }
  };

//+------------------------------------------------------------------+
//| Return latest tick data for markets
//| Syntax: TICKS Format Markets...
//+------------------------------------------------------------------+
class MarketTickCommand: public MqlCommand
  {
public:
		RespValue        *call(const RespArray &command)
		{
		  int total = command.size();
		  if (total < 2) {
		    return new RespError("Illegal arguments for TICKS");
      }
		  string output_format = "sh";
      output_format = dynamic_cast<RespBytes*>(command[1]).getValueAsString();
		  StringToUpper(output_format);

      MqlTick last_tick;
      string market;
		  RespArray *res = new RespArray(total-2);
      for (int i=2; i<total;i++) {
        market = dynamic_cast<RespBytes*>(command[i]).getValueAsString();
        if (!SymbolInfoTick(market, last_tick))
        {
          return new RespError(StringFormat("SymbolInfoTickError: %s: %s", market,
            GetLastError()));
        }

        res.set(i-2, new RespString(StringFormat("symbol='%s' time='%s' bid=%s ask=%s volume=%s", 
              market,
              TimeToString(last_tick.time),
              DoubleToString(last_tick.bid),
              DoubleToString(last_tick.ask),
              DoubleToString(last_tick.volume)
          )));
      }
      return res;
    }
  };

//+------------------------------------------------------------------+
//| Buy at market price                                              |
//| Syntax: BUY Type Symbol Lots Entry SL TP                         |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class BuyCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()<4 || command.size()>7) return new RespError("Invalid number of arguments for command BUY!");
      string direction = "buy";
      string type  =dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      string symbol=dynamic_cast<RespBytes*>(command[2]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());
      double entry=0;
      double stoploss=0;
      double takeprofit=0;
      int ordertype = ParseOrderType(direction,type);
      if(command.size()>4)
      {
         if(ordertype==OP_BUY)
            // input entry is ignored if this is a market order
            entry=FxSymbol::getAsk(symbol);
         else
            entry=StringToDouble(dynamic_cast<RespBytes*>(command[4]).getValueAsString());
      }
      if(command.size()>5)
         stoploss=StringToDouble(dynamic_cast<RespBytes*>(command[5]).getValueAsString());
      if(command.size()>6)
         takeprofit=StringToDouble(dynamic_cast<RespBytes*>(command[6]).getValueAsString());
      //int id=OrderSend(symbol,ordertype,lots,FxSymbol::getAsk(symbol),3,0,0,NULL,0,0,clrNONE);
      int id=OrderSend(symbol,ordertype,lots,entry,3,stoploss,takeprofit,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to buy at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Sell at market price                                             |
//| Syntax: SELL Type Symbol Lots Entry SL TP                        |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class SellCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()<4 || command.size()>7) return new RespError("Invalid number of arguments for command SELL!");
      string direction = "sell";
      string type  =dynamic_cast<RespBytes*>(command[1]).getValueAsString();
      string symbol=dynamic_cast<RespBytes*>(command[2]).getValueAsString();
      double lots=StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());
      double entry = 0;
      double stoploss = 0;
      double takeprofit = 0;
      int ordertype = ParseOrderType(direction,type);
      if(command.size()>4)
      {
         if(ordertype==OP_SELL)
            // input entry is ignored if this is a market order
            entry=FxSymbol::getBid(symbol);
         else
            entry=StringToDouble(dynamic_cast<RespBytes*>(command[4]).getValueAsString());
      }
      if(command.size()>5)
         stoploss=StringToDouble(dynamic_cast<RespBytes*>(command[5]).getValueAsString());
      if(command.size()>6)
         takeprofit=StringToDouble(dynamic_cast<RespBytes*>(command[6]).getValueAsString());
      //int id=OrderSend(symbol,ordertype,lots,FxSymbol::getBid(symbol),3,0,0,NULL,0,0,clrNONE);
      int id=OrderSend(symbol,ordertype,lots,entry,3,stoploss,takeprofit,NULL,0,0,clrNONE);
      if(id==-1)
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to sell at market with error id (%d): %s",
                              ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespInteger(id);
        }
     }
  };
//+------------------------------------------------------------------+
//| Edit a market order                                              |
//| Syntax: EDIT Ticket Entry SL TP                                  |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class EditCommand: public MqlCommand
{
public:
   RespValue   *call(const RespArray &command)
   {
      if(command.size()!=5) return new RespError("Invalid number of arguments for command EDIT! Use 0 on arguments you do not want to change.");
      int ticket=(int)StringToInteger(dynamic_cast<RespBytes*>(command[1]).getValueAsString());
      if(!Order::Select(ticket))
      {
         return new RespError("Order does not exist!");
      }

      double entry = StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
      if (entry <=0) entry = OrderOpenPrice();
      double stoploss = StringToDouble(dynamic_cast<RespBytes*>(command[3]).getValueAsString());
      if (stoploss <=0) stoploss = OrderStopLoss();
      double takeprofit = StringToDouble(dynamic_cast<RespBytes*>(command[4]).getValueAsString());
      if (takeprofit <=0) takeprofit = OrderTakeProfit();

      if(!OrderModify(OrderTicket(), entry, stoploss, takeprofit, 0))
      {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to edit market order #%d with error id (%d): %s",
                              ticket,ec,Mql::getErrorMessage(ec)));
      }
      else
      {
         return new RespString("Ok");
      }
   }
};
//+------------------------------------------------------------------+
//| Close a market order                                             |
//| Syntax: CLOSE Ticket Lots                                        |
//| Results:                                                         |
//|   Success: Order id (RespInteger)                                |
//|   Fail:    RespError                                             |
//+------------------------------------------------------------------+
class CloseCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      if(command.size()!=3 && command.size()!=2) return new RespError("Invalid number of arguments for command CLOSE!");
      int ticket=(int)StringToInteger(dynamic_cast<RespBytes*>(command[1]).getValueAsString());
      if(!Order::Select(ticket))
        {
         return new RespError("Order does not exist!");
        }
      string symbol=Order::Symbol();
      int op=Order::Type();
      double lots=0;
      if(command.size()==2)
        {
         lots=Order::Lots();
        }
      else
        {
         lots=StringToDouble(dynamic_cast<RespBytes*>(command[2]).getValueAsString());
         if(lots<=0) lots=Order::Lots();
        }
      if(!OrderClose(ticket,lots,FxSymbol::priceForClose(symbol,op),3,clrNONE))
        {
         int ec=Mql::getLastError();
         return new RespError(StringFormat("Failed to close market order #%d with error id (%d): %s",
                              ticket,ec,Mql::getErrorMessage(ec)));
        }
      else
        {
         return new RespString("Ok");
        }
     }
  };
//+------------------------------------------------------------------+
//| Quit server connection                                           |
//| Syntax: QUIT                                                     |
//| Results:                                                         |
//|   The server will close the connection                           |
//+------------------------------------------------------------------+
class QuitCommand: public MqlCommand
  {
public:
   RespValue        *call(const RespArray &command)
     {
      return NULL;
     }
  };
//+------------------------------------------------------------------+
