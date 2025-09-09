#!/usr/bin/env python3
"""
Test script for the background token refresh system

Tests the APScheduler integration, admin endpoints, and refresh cycle functionality.
"""

import asyncio
import httpx
import json
from datetime import datetime, timedelta
from typing import Dict, Any

# Test configuration
BASE_URL = "http://localhost:8001/api/v1"
TEST_USER_ID = "refresh-test-device"

class RefreshSystemTester:
    """Test client for refresh system endpoints"""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.client.aclose()
    
    async def test_system_health(self) -> bool:
        """Test system health endpoint"""
        
        print("🔍 Testing: System health check")
        
        url = f"{BASE_URL}/admin/system-health"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ System health SUCCESS:")
                print(f"   Overall status: {result.get('overall_status')}")
                
                services = result.get('services', {})
                for service_name, service_info in services.items():
                    status = service_info.get('status', 'unknown')
                    print(f"   {service_name}: {status}")
                
                return True
            else:
                print(f"❌ System health FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ System health ERROR: {str(e)}")
            return False
    
    async def test_refresh_status(self) -> bool:
        """Test refresh status endpoint"""
        
        print("🔍 Testing: Refresh status check")
        
        url = f"{BASE_URL}/admin/refresh-status"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                refresh_system = result.get('refresh_system', {})
                
                print(f"✅ Refresh status SUCCESS:")
                print(f"   Scheduler running: {refresh_system.get('scheduler_running')}")
                print(f"   Refresh in progress: {refresh_system.get('refresh_in_progress')}")
                print(f"   Next run: {refresh_system.get('next_run_time')}")
                
                stats = refresh_system.get('stats', {})
                print(f"   Total refreshes: {stats.get('total_refreshes', 0)}")
                print(f"   Success rate: {stats.get('success_rate', 0):.2%}")
                
                return True
            else:
                print(f"❌ Refresh status FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Refresh status ERROR: {str(e)}")
            return False
    
    async def test_token_overview(self) -> bool:
        """Test token overview endpoint"""
        
        print("🔍 Testing: Token overview")
        
        url = f"{BASE_URL}/admin/token-overview"
        
        try:
            response = await self.client.get(url)
            
            if response.status_code == 200:
                result = response.json()
                overview = result.get('token_overview', {})
                
                print(f"✅ Token overview SUCCESS:")
                print(f"   Total tokens: {overview.get('total_tokens', 0)}")
                
                by_status = overview.get('tokens_by_status', {})
                print(f"   Valid: {by_status.get('valid', 0)}")
                print(f"   Expiring soon: {by_status.get('expiring_soon', 0)}")
                print(f"   Expired: {by_status.get('expired', 0)}")
                
                devices = overview.get('devices', [])
                if devices:
                    print("   Recent devices:")
                    for user in devices[:3]:  # Show first 3
                        print(f"     {device.get('device_id')}: {device.get('status')} (expires in {device.get('minutes_until_expiry', 'N/A')} min)")
                
                return True
            else:
                print(f"❌ Token overview FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Token overview ERROR: {str(e)}")
            return False
    
    async def test_manual_refresh_trigger(self) -> bool:
        """Test manual refresh trigger"""
        
        print("🔍 Testing: Manual refresh trigger")
        
        url = f"{BASE_URL}/admin/refresh-trigger"
        
        try:
            response = await self.client.post(url)
            
            if response.status_code == 200:
                result = response.json()
                manual_refresh = result.get('manual_refresh', {})
                
                print(f"✅ Manual refresh trigger SUCCESS:")
                print(f"   Status: {manual_refresh.get('status')}")
                print(f"   Message: {manual_refresh.get('message')}")
                
                stats = manual_refresh.get('stats', {})
                if stats:
                    print(f"   Tokens checked: {stats.get('tokens_checked_last_run', 0)}")
                    print(f"   Requiring refresh: {stats.get('tokens_requiring_refresh_last_run', 0)}")
                
                return True
            else:
                print(f"❌ Manual refresh trigger FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Manual refresh trigger ERROR: {str(e)}")
            return False
    
    async def test_token_cleanup(self) -> bool:
        """Test expired token cleanup"""
        
        print("🔍 Testing: Token cleanup")
        
        url = f"{BASE_URL}/admin/token-cleanup"
        
        try:
            response = await self.client.delete(url)
            
            if response.status_code == 200:
                result = response.json()
                cleanup_result = result.get('cleanup_result', {})
                
                print(f"✅ Token cleanup SUCCESS:")
                print(f"   Tokens cleaned: {cleanup_result.get('tokens_cleaned', 0)}")
                print(f"   Message: {cleanup_result.get('message')}")
                
                return True
            else:
                print(f"❌ Token cleanup FAILED: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Token cleanup ERROR: {str(e)}")
            return False
    
    async def create_test_token_near_expiry(self) -> bool:
        """Create a test token that expires soon for testing refresh"""
        
        print("🔍 Creating test token near expiry")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-tokens"
        
        # Create token that expires in 5 minutes (should trigger refresh)
        test_tokens = {
            "access_token": "BQTest123...",
            "refresh_token": "AQTestRefresh456...",
            "expires_in": 300  # 5 minutes
        }
        
        try:
            response = await self.client.post(url, json=test_tokens)
            
            if response.status_code == 200:
                print("✅ Test token created successfully")
                return True
            else:
                print(f"❌ Failed to create test token: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Test token creation ERROR: {str(e)}")
            return False
    
    async def cleanup_test_token(self) -> bool:
        """Clean up test token"""
        
        print("🔍 Cleaning up test token")
        
        url = f"{BASE_URL}/users/{TEST_USER_ID}/spotify-tokens"
        
        try:
            response = await self.client.delete(url)
            
            if response.status_code == 200:
                print("✅ Test token cleaned up")
                return True
            else:
                print(f"⚠️ Test token cleanup: {response.status_code} - {response.text}")
                return True  # Don't fail the test if cleanup fails
                
        except Exception as e:
            print(f"⚠️ Test token cleanup ERROR: {str(e)}")
            return True  # Don't fail the test if cleanup fails

async def main():
    """Run all refresh system tests"""
    
    print("🚀 Starting background refresh system tests...\n")
    
    async with RefreshSystemTester() as tester:
        
        tests = [
            ("System health check", tester.test_system_health),
            ("Refresh status check", tester.test_refresh_status),
            ("Token overview", tester.test_token_overview),
            ("Manual refresh trigger", tester.test_manual_refresh_trigger),
            ("Token cleanup", tester.test_token_cleanup),
        ]
        
        results = []
        
        for test_name, test_func in tests:
            result = await test_func()
            results.append((test_name, result))
            print()
        
        # Test with near-expiry token (optional - requires working Firebase)
        print("🧪 Optional test with near-expiry token:")
        token_created = await tester.create_test_token_near_expiry()
        
        if token_created:
            print("   Waiting 2 seconds...")
            await asyncio.sleep(2)
            
            print("   Triggering manual refresh to test near-expiry token...")
            await tester.test_manual_refresh_trigger()
            print()
            
            # Cleanup
            await tester.cleanup_test_token()
        
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
        print(f"Results: {passed}/{total} core tests passed")
        
        if passed == total:
            print("🎉 All refresh system tests passed!")
            print("\n📋 Next steps:")
            print("   1. Enable Firestore API in Firebase Console")
            print("   2. Configure Spotify API credentials")
            print("   3. Monitor refresh operations in production")
        else:
            print("⚠️  Some tests failed. Check the logs above.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️  Tests interrupted by user")
    except Exception as e:
        print(f"\n💥 Test runner error: {str(e)}")