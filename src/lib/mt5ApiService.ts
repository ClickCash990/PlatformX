import axios from 'axios';
import { ConnectionResponse, AccountInfo, Position } from '../types/mt5';

// Get API URL and key from environment variables
const MT5_API_URL = import.meta.env.VITE_MT5_API_URL || 'https://mt5full2.mtapi.io';
const MT5_API_KEY = import.meta.env.VITE_MT5_API_KEY;

// Store the MT5 token in memory
let mt5Token: string | null = null;

// MT5 API service
const mt5ApiService = {
  // Get the stored token
  getStoredToken: (): string | null => {
    return mt5Token;
  },

  // Connect to MT5 server
  connect: async (credentials: { accountNumber: string; password: string; serverName: string }): Promise<ConnectionResponse> => {
    try {
      console.log('🔄 Connecting to MT5 server:', {
        accountNumber: credentials.accountNumber,
        server: credentials.serverName,
        // Don't log password for security
      });

      // FIXED: Use GET method with credentials as URL parameters
      const params = new URLSearchParams({
        user: credentials.accountNumber,
        password: credentials.password,
        server: credentials.serverName
      });

      const response = await axios.get(`${MT5_API_URL}/ConnectEx?${params.toString()}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      console.log('✅ MT5 connection response:', {
        status: response.status,
        hasData: !!response.data,
        dataType: typeof response.data,
        dataValue: response.data
      });

      // FIXED: Enhanced token extraction logic to handle different response formats
      let extractedToken: string | null = null;

      // Check if the response data itself is a string token
      if (typeof response.data === 'string' && response.data.trim() !== '') {
        extractedToken = response.data.trim();
        console.log('✅ Token extracted directly from response data');
      }
      // Check if token is nested in response data object
      else if (response.data?.token && typeof response.data.token === 'string' && response.data.token.trim() !== '') {
        extractedToken = response.data.token.trim();
        console.log('✅ Token extracted from response.data.token');
      }
      // Check for other possible token field names
      else if (response.data?.id && typeof response.data.id === 'string' && response.data.id.trim() !== '') {
        extractedToken = response.data.id.trim();
        console.log('✅ Token extracted from response.data.id');
      }

      if (extractedToken) {
        mt5Token = extractedToken;
        console.log('✅ MT5 token stored successfully');
        
        return {
          success: true,
          token: extractedToken,
          message: 'Connection successful'
        };
      } else {
        console.warn('⚠️ No valid MT5 token received in response:', response.data);
        
        return {
          success: false,
          token: null,
          message: 'Connection failed: No valid token received from MT5 server'
        };
      }
    } catch (error) {
      console.error('❌ MT5 connection failed:', error);
      
      // Provide more specific error messages
      let errorMessage = 'Failed to connect to MT5 server';
      
      if (axios.isAxiosError(error)) {
        if (error.response) {
          // The request was made and the server responded with a status code
          // that falls out of the range of 2xx
          errorMessage = `MT5 server error: ${error.response.status} - ${error.response.data || 'Unknown error'}`;
          console.error('❌ MT5 server response:', error.response.data);
        } else if (error.request) {
          // The request was made but no response was received
          errorMessage = 'No response from MT5 server. Please check your internet connection.';
        } else {
          // Something happened in setting up the request that triggered an Error
          errorMessage = `Error setting up MT5 connection: ${error.message}`;
        }
      } else if (error instanceof Error) {
        errorMessage = error.message;
      }
      
      return {
        success: false,
        token: null,
        message: errorMessage
      };
    }
  },

  // Disconnect from MT5 server
  disconnect: (): void => {
    mt5Token = null;
    console.log('✅ Disconnected from MT5 server');
  },

  // Get account information
  getAccountInfo: async (): Promise<AccountInfo | null> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      // Get account summary
      const summaryResponse = await axios.get(`${MT5_API_URL}/AccountSummary?id=${mt5Token}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      // Get account details
      const detailsResponse = await axios.get(`${MT5_API_URL}/AccountDetails?id=${mt5Token}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      // Combine the data
      const accountInfo: AccountInfo = {
        balance: summaryResponse.data.balance || 0,
        equity: summaryResponse.data.equity || 0,
        margin: summaryResponse.data.margin || 0,
        freeMargin: summaryResponse.data.freeMargin || 0,
        marginLevel: summaryResponse.data.marginLevel || 0,
        currency: detailsResponse.data.currency || 'USD',
        accountNumber: detailsResponse.data.login || '',
        accountName: detailsResponse.data.name || '',
        serverName: detailsResponse.data.server || '',
        leverage: detailsResponse.data.leverage || 100,
        profit: summaryResponse.data.profit || 0,
        credit: detailsResponse.data.credit || 0
      };

      return accountInfo;
    } catch (error) {
      console.error('❌ Failed to get account info:', error);
      
      // Check if it's an authentication error
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        throw new Error('Authentication failed. Please reconnect to MT5 server.');
      }
      
      throw error;
    }
  },

  // Get open positions
  getPositions: async (): Promise<Position[]> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      // FIXED: Use correct endpoint for open positions
      const response = await axios.get(`${MT5_API_URL}/OpenedOrders?id=${mt5Token}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      // FIXED: Map the response to our Position type with correct field names
      const positions: Position[] = response.data.map((pos: any) => ({
        ticket: pos.ticket,
        symbol: pos.symbol,
        // FIXED: Use orderType field and map correctly
        type: pos.orderType === 0 ? 'Buy' : 'Sell',
        // FIXED: Use lots field with volume as fallback
        volume: pos.lots || pos.volume,
        openPrice: pos.openPrice,
        currentPrice: pos.currentPrice,
        profit: pos.profit,
        swap: pos.swap,
        commission: pos.commission,
        openTime: pos.openTime,
        comment: pos.comment
      }));

      return positions;
    } catch (error) {
      console.error('❌ Failed to get positions:', error);
      
      // Check if it's an authentication error
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        throw new Error('Authentication failed. Please reconnect to MT5 server.');
      }
      
      throw error;
    }
  },

  // Get available symbols
  getSymbols: async (): Promise<string[]> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      const response = await axios.get(`${MT5_API_URL}/SymbolList?id=${mt5Token}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      // Ensure we have an array of strings
      const symbols: string[] = Array.isArray(response.data) 
        ? response.data.filter((symbol: any) => typeof symbol === 'string')
        : [];

      return symbols;
    } catch (error) {
      console.error('❌ Failed to get symbols:', error);
      
      // Check if it's an authentication error
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        throw new Error('Authentication failed. Please reconnect to MT5 server.');
      }
      
      throw error;
    }
  },

  // Get quote for a symbol
  getQuote: async (symbol: string): Promise<{ bid: number; ask: number; time: string } | null> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      const response = await axios.get(`${MT5_API_URL}/GetQuote?id=${mt5Token}&symbol=${symbol}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      if (response.data && typeof response.data.bid === 'number' && typeof response.data.ask === 'number') {
        return {
          bid: response.data.bid,
          ask: response.data.ask,
          time: new Date().toISOString()
        };
      }

      return null;
    } catch (error) {
      console.error(`❌ Failed to get quote for ${symbol}:`, error);
      return null;
    }
  },

  // Send an order
  sendOrder: async (order: {
    symbol: string;
    action: 'BUY' | 'SELL';
    volume: number;
    price?: number;
    sl?: number;
    tp?: number;
  }): Promise<any> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      // Convert action to MT5 API format
      const operation = order.action === 'BUY' ? 'Buy' : 'Sell';

      // FIXED: Use GET method instead of POST for OrderSend
      // Build the request parameters
      const params = new URLSearchParams({
        id: mt5Token,
        symbol: order.symbol,
        operation: operation,
        volume: order.volume.toString(),
        slippage: '10',
        expertID: '0'
      });

      // Add optional parameters if provided
      if (order.price) {
        params.append('price', order.price.toString());
      }
      if (order.sl) {
        params.append('stoploss', order.sl.toString());
      }
      if (order.tp) {
        params.append('takeprofit', order.tp.toString());
      }

      // Make the request using GET method
      const response = await axios.get(`${MT5_API_URL}/OrderSend?${params.toString()}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      return response.data;
    } catch (error) {
      console.error('❌ Failed to send order:', error);
      
      // Check if it's an authentication error
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        throw new Error('Authentication failed. Please reconnect to MT5 server.');
      }
      
      throw error;
    }
  },

  // Close a position
  closePosition: async (ticket: number, volume?: number): Promise<any> => {
    try {
      if (!mt5Token) {
        throw new Error('Not connected to MT5 server');
      }

      // FIXED: Use GET method instead of POST for OrderClose
      // Build the request parameters
      const params = new URLSearchParams({
        id: mt5Token,
        ticket: ticket.toString(),
        slippage: '10'
      });

      // Add volume if provided
      if (volume) {
        params.append('lots', volume.toString());
      }

      // Make the request using GET method
      const response = await axios.get(`${MT5_API_URL}/OrderClose?${params.toString()}`, {
        headers: {
          'apikey': MT5_API_KEY
        }
      });

      // Add format description for debugging
      const result = response.data;
      result.formatDescription = volume ? `Specified volume: ${volume}` : 'Auto-detected volume';

      return result;
    } catch (error) {
      console.error(`❌ Failed to close position ${ticket}:`, error);
      
      // Check if it's an authentication error
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        throw new Error('Authentication failed. Please reconnect to MT5 server.');
      }
      
      throw error;
    }
  }
};

export default mt5ApiService;