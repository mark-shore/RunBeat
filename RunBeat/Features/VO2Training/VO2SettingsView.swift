//
//  VO2SettingsView.swift
//  RunBeat
//
//  Settings view for VO2 Max training
//

import SwiftUI

struct VO2SettingsView: View {
    @StateObject private var settingsManager = VO2SettingsManager()
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    AppCard {
                        VStack(spacing: AppSpacing.md) {
                            Text("Zone Announcements")
                                .font(AppTypography.title2)
                                .foregroundColor(AppColors.onBackground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                Text("Announce heart rate zone changes during training")
                                    .font(AppTypography.callout)
                                    .foregroundColor(AppColors.onBackground)
                                
                                Spacer()
                                
                                AppToggle(isOn: $settingsManager.announcementsEnabled)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.top, AppSpacing.lg)
            }
        }
        .navigationTitle("VO₂ Training Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AppBackButton {
                    isPresented = false
                }
            }
        }
    }
}