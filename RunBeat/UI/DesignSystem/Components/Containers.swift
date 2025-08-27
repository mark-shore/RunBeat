//
//  Containers.swift
//  RunBeat
//
//  Semantic container components for consistent spacing architecture
//

import SwiftUI
import Foundation

// MARK: - Container Constants (self-contained)

private enum ContainerSpacing {
    static let screenHorizontal: CGFloat = 4
    static let screenVertical: CGFloat = 8
    static let modalHorizontal: CGFloat = 4
    static let modalVertical: CGFloat = 8
    static let defaultSpacing: CGFloat = 16
}

// MARK: - Screen Container

struct ScreenContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, ContainerSpacing.screenHorizontal)
            .padding(.vertical, ContainerSpacing.screenVertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Modal Container

struct ModalContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, ContainerSpacing.modalHorizontal)
            .padding(.vertical, ContainerSpacing.modalVertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Section Container

struct SectionContainer<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = ContainerSpacing.defaultSpacing, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.spacing = spacing
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        // Section containers don't add additional padding
    }
}

// MARK: - Component Container

struct ComponentContainer<Content: View>: View {
    let content: Content
    let internalPadding: CGFloat
    
    init(internalPadding: CGFloat = ContainerSpacing.defaultSpacing, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.internalPadding = internalPadding
    }
    
    var body: some View {
        content
            .padding(internalPadding)
    }
}

// MARK: - Modal Presentation Extension

extension View {
    func asModal<ModalContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            ModalContainer {
                content()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Preview

#Preview {
    ScreenContainer {
        VStack(spacing: 24) {
            Text("Screen Container")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            SectionContainer {
                Text("Section 1")
                Text("Section 2")
            }
            
            ComponentContainer {
                Text("Component with internal padding")
                    .background(Color.blue.opacity(0.2))
            }
        }
    }
    .background(Color.black)
}
