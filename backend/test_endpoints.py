#!/usr/bin/env python3
"""
Test script for Spotify token management endpoints

Tests the Firestore REST API integration and token CRUD operations.
"""

import asyncio
import httpx
import json
from datetime import datetime, timedelta
from typing import Dict, Any

# Test configuration
BASE_URL = "http://localhost:8001/api/v1"
TEST_USER_ID = "test-user-123"

# Sample token data for testing
SAMPLE_TOKENS = {
    "access_token": "BQAbcd123...",  # Fake token for testing
    "refresh_token": "AQDefg456...",  # Fake refresh token for testing
    "expires_in": 3600
}

class EndpointTester:
    """Test client for Spotify token endpoints"""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def test_store_tokens(self) -> bool:
        """Test storing Spotify tokens"""
        
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
        """Test retrieving Spotify token"""
        
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
        """Test deleting Spotify tokens"""
        
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
    
    async def test_health_check(self) -> bool:
        """Test health check endpoint"""
        
        print("🔍 Testing: Health check")
        
        url = f"{BASE_URL}/health"
        
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

async def main():
    """Run all endpoint tests"""
    
    print("🚀 Starting Spotify token endpoint tests...\n")
    
    async with EndpointTester() as tester:
        
        # Test health check first
        health_ok = await tester.test_health_check()
        print()
        
        if not health_ok:
            print("❌ Health check failed, skipping other tests")
            return
        
        # Run token CRUD tests
        tests = [
            ("Store tokens", tester.test_store_tokens),
            ("Get token", tester.test_get_token),
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
        print("=" * 40)
        
        passed = 0
        total = len(results)
        
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{status} {test_name}")
            if result:
                passed += 1
        
        print("=" * 40)
        print(f"Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed!")
        else:
            print("⚠️  Some tests failed. Check the logs above.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️  Tests interrupted by user")
    except Exception as e:
        print(f"\n💥 Test runner error: {str(e)}")