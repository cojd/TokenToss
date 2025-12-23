//
//  SubabaseConfig.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//

import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let client: SupabaseClient
    let serviceClient: SupabaseClient // Service role client for admin operations
    
    private init() {
        // Supabase configuration
        let supabaseURLString = "https://yxyujiciywhwtckkyffr.supabase.co"
        let supabaseAPIKey = "sb_publishable_jG6-W4Z7wYroNCeZuo18LQ_9oR0_oLr"
        let supabaseServiceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4eXVqaWNpeXdod3Rja2t5ZmZyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjQyODQ4MywiZXhwIjoyMDgyMDA0NDgzfQ.HHgfPXqRGuTC04evMamFs1Vy0C_yylgVCQSOT_gVPao" // Replace with actual service key
        
        guard let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Invalid Supabase URL: \(supabaseURLString)")
        }
        
        // Regular client for user operations
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAPIKey
        )
        
        // Service role client for admin operations (bypasses RLS)
        serviceClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseServiceKey
        )
        
        // Log configuration (without exposing sensitive data)
        print("✅ Supabase client initialized")
        print("   URL: \(supabaseURL.absoluteString)")
        print("   API Key: \(String(supabaseAPIKey.prefix(20)))...")
    }
}

// Global accessors
let supabase = SupabaseConfig.shared.client
let supabaseService = SupabaseConfig.shared.serviceClient // For admin operations
