#!/usr/bin/env python3
"""
Test script for user-scoped Spotify token management endpoints

Tests the Firebase anonymous user integration and token CRUD operations.
"""

import asyncio
import httpx
import json
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any

# Test configuration
BASE_URL = "https://runbeat-production.up.railway.app"
TEST_USER_ID = "testuser12345678901234567890"  # Mock Firebase anonymous user ID

# Sample token data for testing
SAMPLE_TOKENS = {
    "access_token": "BQAbcd123...",  # Fake token for testing
    "refresh_token": "AQDefg456...",  # Fake refresh token for testing
    "expires_in": 3600
}

class UserEndpointTester:
    """Test client for user-scoped Spotify token endpoints"""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def test_store_tokens(self) -> bool:
        """Test storing Spotify tokens for a user"""
        
        print(f"🔍 Testing: Store tokens for user {TEST_USER_ID}")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-tokens"
        
        try:
            response = await self.client.post(url, json=SAMPLE_TOKENS)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Store tokens SUCCESS: {result}")
                return True
            else:
                print(f"❌ Store tokens FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Store tokens ERROR: {str(e)}")
            return False
    
    async def test_get_token(self) -> bool:
        """Test retrieving Spotify token for a user"""
        
        print(f"🔍 Testing: Get token for user {TEST_USER_ID}")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-token"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Get token SUCCESS: access_token={result['access_token'][:10]}...")
                return True
            else:
                print(f"❌ Get token FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Get token ERROR: {str(e)}")
            return False
    
    async def test_delete_tokens(self) -> bool:
        """Test deleting Spotify tokens for a user"""
        
        print(f"🔍 Testing: Delete tokens for user {TEST_USER_ID}")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-tokens"
        
        try:
            response = await self.client.delete(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Delete tokens SUCCESS: {result}")
                return True
            else:
                print(f"❌ Delete tokens FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Delete tokens ERROR: {str(e)}")
            return False
    
    async def test_get_token_after_delete(self) -> bool:
        """Test retrieving token after deletion (should return 404)"""
        
        print(f"🔍 Testing: Get token after deletion (expecting 404)")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-token"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 404:
                print(f"✅ Get token after delete SUCCESS: {response.status_code} (expected 404)")
                return True
            else:
                print(f"❌ Get token after delete FAILED: Expected 404, got {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Get token after delete ERROR: {str(e)}")
            return False
    
    async def test_invalid_user_id(self) -> bool:
        """Test invalid user ID validation"""
        
        print("🔍 Testing: Invalid user ID validation")
        
        invalid_user_ids = [
            "short",  # Too short
            "thisuseriditoooooooolongforFirebaseUID123456789",  # Too long
            "invalid-user-with-dashes",  # Contains invalid characters
            "user@email.com",  # Contains invalid characters
        ]
        
        for invalid_id in invalid_user_ids:
            url = f"{BASE_URL}/users/{invalid_id}/spotify-tokens"
            
            try:
                response = await self.client.post(url, json=SAMPLE_TOKENS)
                
                if response.status_code == 400:
                    print(f"✅ Invalid user ID validation SUCCESS for '{invalid_id}': {response.status_code}")
                else:
                    print(f"❌ Invalid user ID validation FAILED for '{invalid_id}': Expected 400, got {response.status_code}")
                    return False
                    
            except Exception as e:
                print(f"❌ Invalid user ID validation ERROR for '{invalid_id}': {str(e)}")
                return False
        
        return True
    
    async def test_spotify_api_proxy(self) -> bool:
        """Test Spotify API proxy endpoint"""
        
        print(f"🔍 Testing: Spotify API proxy")
        
        # First store tokens for testing
        await self.test_store_tokens()
        
        url = f"{BASE_URL}/spotify/api-proxy"
        
        proxy_request = {
            "user_id": TEST_USER_ID,
            "endpoint": "me",
            "method": "GET"
        }
        
        try:
            response = await self.client.post(url, json=proxy_request)
            
            # This will likely fail with token errors since we're using fake tokens,
            # but we should get a proper error response, not a 500
            if response.status_code in [200, 400, 401]:
                print(f"✅ API proxy SUCCESS: {response.status_code} (expected response)")
                return True
            else:
                print(f"❌ API proxy FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ API proxy ERROR: {str(e)}")
            return False
    
    async def test_token_refresh(self) -> bool:
        """Test token refresh endpoint"""
        
        print(f"🔍 Testing: Token refresh")
        
        url = f"{BASE_URL}/spotify/refresh-token"
        
        refresh_request = {
            "user_id": TEST_USER_ID,
            "refresh_token": "fake_refresh_token_for_testing"
        }
        
        try:
            response = await self.client.post(url, json=refresh_request)
            
            # This will likely fail with Spotify API errors since we're using fake tokens,
            # but we should get a proper error response, not a 500
            if response.status_code in [200, 400, 401]:
                print(f"✅ Token refresh SUCCESS: {response.status_code} (expected response)")
                return True
            else:
                print(f"❌ Token refresh FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Token refresh ERROR: {str(e)}")
            return False
    
    async def test_health_check(self) -> bool:
        """Test health check endpoint"""
        
        print("🔍 Testing: Health check")
        
        url = f"{BASE_URL}/api/v1/health"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Health check SUCCESS: {result}")
                return True
            else:
                print(f"❌ Health check FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Health check ERROR: {str(e)}")
            return False

    async def test_spotify_config(self) -> bool:
        """Test Spotify configuration endpoint"""
        
        print("🔍 Testing: Spotify config")
        
        url = f"{BASE_URL}/spotify/config"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Spotify config SUCCESS: client_id present = {'client_id' in result}")
                return True
            else:
                print(f"❌ Spotify config FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Spotify config ERROR: {str(e)}")
            return False

async def main():
    """Run all user endpoint tests"""
    
    print("🚀 Starting user-scoped Spotify token endpoint tests...\n")
    
    async with UserEndpointTester() as tester:
        
        # Test health check first
        health_ok = await tester.test_health_check()
        print()
        
        if not health_ok:
            print("❌ Health check failed, skipping other tests")
            return
        
        # Run all tests
        tests = [
            ("Spotify config", tester.test_spotify_config),
            ("Invalid user ID validation", tester.test_invalid_user_id),
            ("Store tokens", tester.test_store_tokens),
            ("Get token", tester.test_get_token),
            ("Token refresh", tester.test_token_refresh),
            ("Spotify API proxy", tester.test_spotify_api_proxy),
            ("Delete tokens", tester.test_delete_tokens),
            ("Get token after delete", tester.test_get_token_after_delete),
        ]
        
        results = []
        
        for test_name, test_func in tests:
            result = await test_func()
            results.append((test_name, result))
            print()
        
        # Summary
        print("📊 Test Results Summary:")
        print("=" * 50)
        
        passed = 0
        total = len(results)
        
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{status} {test_name}")
            if result:
                passed += 1
        
        print("=" * 50)
        print(f"Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed!")
        else:
            print("⚠️  Some tests failed. Check the logs above.")
        
        print(f"\n📝 Test used user ID: {TEST_USER_ID}")
        print("💡 To test with real tokens, update SAMPLE_TOKENS with valid Spotify tokens")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️  Tests interrupted by user")
    except Exception as e:
        print(f"\n💥 Test runner error: {str(e)}")