#!/usr/bin/env python3
import json
import os
from datetime import datetime, timedelta

class EndpointStorage:
    """
    Local storage manager for chain endpoints
    """
    def __init__(self, cache_dir="cache"):
        self.cache_dir = cache_dir
        self.cache_file = os.path.join(cache_dir, "endpoints_cache.json")
        self.cache_duration = timedelta(hours=24)  # Cache valid for 24 hours
        
        # Create cache directory if it doesn't exist
        os.makedirs(cache_dir, exist_ok=True)
        
        # Create cache file with empty JSON object if it doesn't exist
        if not os.path.exists(self.cache_file):
            with open(self.cache_file, 'w') as f:
                json.dump({}, f)
        
    def save_endpoints(self, chain_id: str, endpoints: list):
        """Save endpoints to storage"""
        cache_data = self.load_cache()
        cache_data[chain_id] = {
            "endpoints": endpoints,
            "timestamp": datetime.now().isoformat()
        }
        
        with open(self.cache_file, 'w') as f:
            json.dump(cache_data, f, indent=2)
            
    def get_endpoints(self, chain_id: str) -> list:
        """Get endpoints from storage if they're still valid"""
        cache_data = self.load_cache()
        
        if chain_id in cache_data:
            cached = cache_data[chain_id]
            cached_time = datetime.fromisoformat(cached["timestamp"])
            
            # Return cached endpoints if they're still valid
            if datetime.now() - cached_time < self.cache_duration:
                return cached["endpoints"]
                
        return []
        
    def load_cache(self) -> dict:
        """Load storage from file"""
        try:
            with open(self.cache_file) as f:
                data = f.read().strip()
                if not data:  # If file is empty
                    return {}
                return json.loads(data)
        except json.JSONDecodeError:  # If JSON is invalid
            return {}
        except Exception as e:
            print(f"Error loading storage: {e}")
            return {} 