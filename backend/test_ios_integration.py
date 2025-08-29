#!/usr/bin/env python3
"""
iOS Integration Test Script

Tests the FastAPI backend endpoints that will be used by the iOS app
for Spotify token management.
"""

import asyncio
import httpx
from datetime import datetime
from typing import Dict, Any

# Test configuration
BASE_URL = "http://localhost:8001/api/v1"
TEST_DEVICE_ID = "ios-integration-test-device"

# Simulate iOS token data
IOS_TOKEN_DATA = {
    "access_token": "BQAiOS_TestToken_...",
    "refresh_token": "AQAiOS_RefreshToken_...",
    "expires_in": 3600  # 1 hour
}

class iOSIntegrationTester:
    """Test client simulating iOS app behavior"""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def test_device_token_flow(self) -> bool:
        """Test the complete device token flow as iOS app would use it"""
        
        print("🍎 Testing iOS app token flow...")
        
        # Step 1: Store tokens after OAuth (iOS app would do this)
        print("\n1️⃣ Storing tokens after OAuth completion...")
        store_success = await self._store_tokens()
        
        if not store_success:
            print("❌ Token storage failed")
            return False
        
        # Step 2: Get fresh token for API calls (iOS app would do this)
        print("\n2️⃣ Getting fresh token for API calls...")
        token_data = await self._get_fresh_token()
        
        if not token_data:
            print("❌ Token retrieval failed")
            return False
        
        # Step 3: Simulate multiple API calls (background playlist switching)
        print("\n3️⃣ Simulating background playlist switching...")
        api_success = await self._simulate_background_operations()
        
        # Step 4: Clean up tokens (iOS app logout)
        print("\n4️⃣ Cleaning up tokens on logout...")
        cleanup_success = await self._cleanup_tokens()
        
        success = store_success and token_data and api_success and cleanup_success
        
        if success:
            print("\n✅ Complete iOS integration flow successful!")
        else:
            print("\n❌ iOS integration flow had issues")
        
        return success
    
    async def _store_tokens(self) -> bool:
        """Simulate iOS app storing tokens after OAuth"""
        
        url = f"{BASE_URL}/devices/{TEST_DEVICE_ID}/spotify-tokens"
        
        try:
            response = await self.client.post(url, json=IOS_TOKEN_DATA)
            
            if response.status_code == 200:
                result = response.json()
                print(f"   ✅ Tokens stored: {result['message']}")
                return True
            else:
                print(f"   ❌ Storage failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"   ❌ Storage error: {str(e)}")
            return False
    
    async def _get_fresh_token(self) -> Dict[str, Any]:
        """Simulate iOS app getting fresh token for API calls"""
        
        url = f"{BASE_URL}/devices/{TEST_DEVICE_ID}/spotify-token"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                token_data = response.json()
                access_token = token_data.get("access_token", "")
                expires_at = token_data.get("expires_at", "")
                
                print(f"   ✅ Fresh token received")
                print(f"   📝 Token: {access_token[:20]}...")
                print(f"   ⏰ Expires: {expires_at}")
                
                return token_data
            else:
                print(f"   ❌ Token retrieval failed: {response.status_code} - {response.text}")
                return {}
                
        except Exception as e:
            print(f"   ❌ Token retrieval error: {str(e)}")
            return {}
    
    async def _simulate_background_operations(self) -> bool:
        """Simulate iOS app making multiple API calls in background"""
        
        print("   🎵 Simulating playlist switches during training...")
        
        # Simulate multiple token requests like iOS app would make during training
        operations = [
            "High intensity playlist switch",
            "Track status check", 
            "Rest playlist switch",
            "Current track info",
            "Final playlist switch"
        ]
        
        success_count = 0
        
        for i, operation in enumerate(operations, 1):
            print(f"   📱 Operation {i}/5: {operation}")
            
            # Each operation would request a fresh token
            token_data = await self._get_fresh_token()
            
            if token_data and token_data.get("access_token"):
                success_count += 1
                print(f"      ✅ Token available for {operation}")
                
                # Small delay to simulate real usage
                await asyncio.sleep(0.5)
            else:
                print(f"      ❌ No token for {operation}")
        
        success_rate = success_count / len(operations)
        print(f"   📊 Background operations: {success_count}/{len(operations)} successful ({success_rate:.0%})")
        
        return success_rate >= 0.8  # 80% success rate threshold
    
    async def _cleanup_tokens(self) -> bool:
        """Simulate iOS app cleaning up tokens on logout"""
        
        url = f"{BASE_URL}/devices/{TEST_DEVICE_ID}/spotify-tokens"
        
        try:
            response = await self.client.delete(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"   ✅ Tokens cleaned up: {result['message']}")
                return True
            else:
                print(f"   ❌ Cleanup failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"   ❌ Cleanup error: {str(e)}")
            return False
    
    async def test_backend_health(self) -> bool:
        """Test backend health for iOS integration"""
        
        print("🏥 Testing backend health...")
        
        try:
            url = f"{BASE_URL}/health"
            response = await self.client.get(url)
            
            if response.status_code == 200:
                health_data = response.json()
                print(f"   ✅ Backend healthy: {health_data['status']}")
                return True
            else:
                print(f"   ❌ Backend unhealthy: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"   ❌ Health check error: {str(e)}")
            return False

async def main():
    """Run iOS integration tests"""
    
    print("📱 RunBeat iOS Backend Integration Tests\n")
    
    async with iOSIntegrationTester() as tester:
        
        # Test backend health first
        health_ok = await tester.test_backend_health()
        
        if not health_ok:
            print("\n💥 Backend is not healthy, aborting tests")
            return
        
        print()
        
        # Test complete token flow
        flow_success = await tester.test_device_token_flow()
        
        print(f"\n{'='*60}")
        print("📋 iOS Integration Test Results:")
        print(f"{'='*60}")
        
        if flow_success:
            print("✅ PASS - iOS integration ready")
            print("\n📱 Next Steps:")
            print("   1. Build and run RunBeat iOS app")
            print("   2. Complete Spotify OAuth in app") 
            print("   3. Start VO2 training and verify background playlist switching")
            print("   4. Monitor backend logs for token requests")
        else:
            print("❌ FAIL - iOS integration has issues")
            print("\n🔧 Troubleshooting:")
            print("   1. Check backend service is running on port 8001")
            print("   2. Verify Firebase configuration")
            print("   3. Review backend logs for errors")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️ Tests interrupted by user")
    except Exception as e:
        print(f"\n💥 Test runner error: {str(e)}")