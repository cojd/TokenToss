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
    
    private init() {
        // Supabase configuration
        let supabaseURLString = "https://yxyujiciywhwtckkyffr.supabase.co"
        let supabaseAPIKey = "sb_publishable_jG6-W4Z7wYroNCeZuo18LQ_9oR0_oLr"
        
        guard let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Invalid Supabase URL: \(supabaseURLString)")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAPIKey
        )
        
        // Log configuration (without exposing sensitive data)
        print("✅ Supabase client initialized")
        print("   URL: \(supabaseURL.absoluteString)")
        print("   API Key: \(String(supabaseAPIKey.prefix(20)))...")
    }
}

// Global accessor
let supabase = SupabaseConfig.shared.client
