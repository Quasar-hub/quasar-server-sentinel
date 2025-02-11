#!/usr/bin/env python3
import requests
import json
from typing import List, Dict
import logging
import os
from endpoint_storage import EndpointStorage
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChainEndpoints:
    """Manager for chain endpoints with file storage"""
    
    GITHUB_RAW_BASE = "https://raw.githubusercontent.com/ping-pub/ping.pub/main/chains/mainnet/"
    
    def __init__(self):
        self.headers = {
            'Accept': 'application/vnd.github.v3+json'
        }
        self.storage = EndpointStorage()

    def _extract_api_endpoints(self, api_data) -> List[str]:
        """
        Extract API endpoints from different JSON formats
        
        Handles formats:
        1. List of strings: ["url1", "url2"]
        2. List of dicts with address: [{"address": "url1"}, {"address": "url2"}]
        3. Mixed list: ["url1", {"address": "url2", "provider": "name"}]
        4. Single string: "url"
        """
        endpoints = []
        
        if isinstance(api_data, list):
            for item in api_data:
                if isinstance(item, dict) and 'address' in item:
                    endpoints.append(item['address'])
                elif isinstance(item, str):
                    endpoints.append(item)
        elif isinstance(api_data, str):
            endpoints.append(api_data)
            
        return endpoints

    def _check_endpoint(self, endpoint: str) -> bool:
        """Check if endpoint is working"""
        try:
            response = requests.get(
                f"{endpoint}/status",  # RPC endpoint check
                timeout=5
            )
            return response.status_code == 200
        except:
            return False

    def get_endpoints(self, chain_id: str) -> List[str]:
        """Get list of API endpoints for a specific chain"""
        # Try getting from local storage first
        endpoints = self.storage.get_endpoints(chain_id)
        if endpoints:
            # Verify first endpoint is working
            if self._check_endpoint(endpoints[0]):
                return endpoints
            logger.info(f"Stored endpoints for {chain_id} not working, fetching new ones")
        
        # If not in storage or not working, get from GitHub
        try:
            # First try direct chain_id
            logger.info(f"Fetching config for {chain_id}")
            response = requests.get(f"{self.GITHUB_RAW_BASE}{chain_id}.json")
            
            if response.status_code == 404:
                # If not found, try to find by registry_name in all files
                logger.info("Chain not found, searching in all configurations...")
                all_chains = requests.get("https://api.github.com/repos/ping-pub/ping.pub/contents/chains/mainnet")
                if all_chains.status_code == 200:
                    for item in all_chains.json():
                        if item['name'].endswith('.json'):
                            config_response = requests.get(item['download_url'])
                            if config_response.status_code == 200:
                                config = config_response.json()
                                if (config.get('registry_name') == chain_id or 
                                    config.get('chain_name') == chain_id):
                                    response = config_response
                                    break
            
            if response.status_code == 200:
                config = response.json()
                rpc_data = config.get('rpc', [])  # Get RPC endpoints instead of API
                endpoints = self._extract_api_endpoints(rpc_data)  # Extract RPC endpoints
                
                # Filter working endpoints
                working_endpoints = [
                    endpoint for endpoint in endpoints 
                    if self._check_endpoint(endpoint)
                ]
                
                if working_endpoints:
                    logger.info(f"Found {len(working_endpoints)} working endpoints for {chain_id}")
                    # Save to local storage
                    self.storage.save_endpoints(chain_id, working_endpoints)
                    return working_endpoints
                else:
                    logger.warning(f"No working endpoints found for {chain_id}")
            else:
                logger.error(f"Failed to get config for {chain_id}: {response.status_code}")
        except Exception as e:
            logger.error(f"Error fetching config for {chain_id}: {e}")
        
        return []

# Singleton instance
chain_endpoints = ChainEndpoints()

def test_endpoints():
    """Test function to demonstrate functionality"""
    
    # Test 1: Get all available chain configs
    print("\n=== Test 1: Available Chains ===")
    try:
        response = requests.get("https://api.github.com/repos/ping-pub/ping.pub/contents/chains/mainnet")
        if response.status_code == 200:
            chains = [
                item['name'].replace('.json', '') 
                for item in response.json() 
                if item['name'].endswith('.json') and not item['name'].endswith('.disabled')
            ]
            print(f"Total chains available: {len(chains)}")
            print("\nFirst 10 chains:")
            for chain in sorted(chains[:10]):
                print(f"  - {chain}")
            print("...")
    except Exception as e:
        print(f"Error getting chain list: {e}")

    # Test 2: Test popular chains RPC endpoints
    print("\n=== Test 2: Popular Chains RPC Endpoints ===")
    test_chains = ['cosmoshub', 'osmosis', 'celestia', 'juno', 'stargaze']
    for chain in test_chains:
        print(f"\nTesting {chain}:")
        endpoints = chain_endpoints.get_endpoints(chain)
        print(f"Found {len(endpoints)} working RPC endpoints:")
        for endpoint in endpoints:
            print(f"  - {endpoint}")

    # Test 3: Test cache functionality
    print("\n=== Test 3: Cache Test ===")
    chain = 'cosmoshub'
    print(f"First request for {chain} (might fetch from GitHub):")
    start_time = time.time()
    endpoints1 = chain_endpoints.get_endpoints(chain)
    time1 = time.time() - start_time
    
    print(f"Second request for {chain} (should use cache):")
    start_time = time.time()
    endpoints2 = chain_endpoints.get_endpoints(chain)
    time2 = time.time() - start_time
    
    print(f"\nFirst request time: {time1:.2f}s")
    print(f"Second request time: {time2:.2f}s")
    print(f"Cache speedup: {time1/time2:.1f}x")

    # Test 4: Test RPC endpoint health check
    print("\n=== Test 4: RPC Endpoint Health Check ===")
    chain = 'osmosis'
    endpoints = chain_endpoints.get_endpoints(chain)
    print(f"\nChecking {len(endpoints)} RPC endpoints for {chain}:")
    for endpoint in endpoints:
        start_time = time.time()
        is_working = chain_endpoints._check_endpoint(endpoint)
        response_time = time.time() - start_time
        status = "✅" if is_working else "❌"
        print(f"{status} {endpoint} - Response time: {response_time:.2f}s")

def test_endpoint_extraction():
    """Test different JSON formats for endpoint extraction"""
    print("\n=== Test 6: JSON Format Handling ===")
    
    # Test Format 1: Mixed list (strings and objects) - Axelar example
    print("\nTesting Format 1 (Axelar-style):")
    axelar_format = [
        "https://rpc-axelar.imperator.co:443",
        "https://axelar-rpc.quickapi.com:443",
        {
            "address": "https://tm.axelar.lava.build",
            "provider": "Lava network"
        }
    ]
    endpoints = chain_endpoints._extract_api_endpoints(axelar_format)
    print(f"Found {len(endpoints)} RPC endpoints:")
    for endpoint in endpoints:
        print(f"  - {endpoint}")

    # Test Format 2: List of objects only - Andromeda example
    print("\nTesting Format 2 (Andromeda-style):")
    andromeda_format = [
        {
            "address": "https://rpc.andromeda-1.andromeda.aviaone.com",
            "provider": "AVIAONE"
        },
        {
            "address": "https://andromeda-rpc.lavenderfive.com:443",
            "provider": "Lavender.Five Nodes 🐝"
        }
    ]
    endpoints = chain_endpoints._extract_api_endpoints(andromeda_format)
    print(f"Found {len(endpoints)} RPC endpoints:")
    for endpoint in endpoints:
        print(f"  - {endpoint}")

    # Test Format 3: List of objects with registry name - Cosmos example
    print("\nTesting Format 3 (Cosmos-style):")
    cosmos_format = [
        {"provider": "cosmos.directory", "address": "https://rpc.cosmos.directory/cosmoshub"},
        {"provider": "Lava network", "address": "https://cosmoshub.tendermintrpc.lava.build"}
    ]
    endpoints = chain_endpoints._extract_api_endpoints(cosmos_format)
    print(f"Found {len(endpoints)} RPC endpoints:")
    for endpoint in endpoints:
        print(f"  - {endpoint}")

    # Test real chains with different formats
    print("\nTesting real chains with different formats:")
    test_chains = ['axelar', 'andromeda', 'cosmoshub']
    for chain in test_chains:
        print(f"\n{chain}:")
        endpoints = chain_endpoints.get_endpoints(chain)
        print(f"Found {len(endpoints)} working RPC endpoints:")
        for endpoint in endpoints:
            print(f"  - {endpoint}") 

if __name__ == "__main__":
    import sys
    import time
    
    if len(sys.argv) > 1:
        # Get endpoints for specific chain
        chain_id = sys.argv[1]
        logger.info(f"Getting endpoints for {chain_id}...")
        endpoints = chain_endpoints.get_endpoints(chain_id)
        if endpoints:
            # Print endpoints space-separated for bash script
            print(" ".join(endpoints))
        else:
            logger.warning("No working endpoints found")
            print("")  # Print empty line for bash script
    else:
        # Run tests
        test_endpoints()
        test_endpoint_extraction() 