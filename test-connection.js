import axios from 'axios';

const MT4_HOST = process.env.MT4_HOST || '192.168.50.161';
const MT4_PORT = process.env.MT4_PORT || '8080';

async function testConnection() {
  try {
    console.log(`Testing connection to MT4 HTTP Bridge at ${MT4_HOST}:${MT4_PORT}`);
    
    // Test health endpoint
    const healthResponse = await axios.get(`http://${MT4_HOST}:${MT4_PORT}/api/health`, {
      timeout: 5000
    });
    
    console.log('✅ Health check successful:', healthResponse.data);
    
    // Test account info (this will fail if MT4 is not running with EA)
    try {
      const accountResponse = await axios.get(`http://${MT4_HOST}:${MT4_PORT}/api/account`, {
        timeout: 5000
      });
      console.log('✅ Account info retrieved:', accountResponse.data);
    } catch (error) {
      console.log('⚠️ Account info failed (MT4 may not be running with EA):', error.message);
    }
    
  } catch (error) {
    console.error('❌ Connection failed:', error.message);
    console.log('\nTroubleshooting:');
    console.log('1. Ensure the HTTP Bridge is running on Windows machine');
    console.log('2. Check Windows firewall allows port 8080');
    console.log('3. Verify the IP address 192.168.50.161 is correct');
    console.log('4. Make sure both machines are on the same network');
  }
}

testConnection();