//
//  WelcomeSheet.swift
//  Timer
//
//  Created by Kristian Emil on 19/09/2024.
//

import SwiftUI

struct WelcomeScreen: View {
    
    @AppStorage("aboutToShowWelcomeScreen") var aboutToShowWelcomeScreen = true
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TimerViewModel
    
    @State private var viewAppears: Bool = false
    @State private var buttonSize: Double = 1.0
    @State private var buttonColor: Color = .orange
    @State private var overlaySize: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.blue)
                    .ignoresSafeArea()
                
                
                VStack(alignment: .center, spacing: geometry.size.height * 0.02) {
                    Spacer()
                    VStack(spacing: geometry.size.height * 0.02) {
                        Text("Just one thing ☝️")
                            .font(.largeTitle).bold()
                        Text("Press and hold the button to reset the timer.\nAccept notifications if needed.")
                            .multilineTextAlignment(.center)
                    }
                    .opacity(viewAppears ? 1 : 0)
                    .offset(y: viewAppears ? 0 : -100)
                    
                    
                    ZStack {
                        
                        RoundedRectangle(cornerRadius: 25)
                            .fill(buttonColor)
                            .overlay {
                                Circle()
                                    .foregroundStyle(.white.opacity(0.2))
                                    .allowsHitTesting(false)
                                    .scaleEffect(overlaySize, anchor: .center)
                                
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .padding()
                        VStack(spacing: geometry.size.height * 0.01) {
                            Text("Continue")
                                .font(.custom("Stormfaze", size: 40))
                            Text("Press and hold")
                                .bold()
                                .offset(y: -5)
                        }
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.2)
                        .foregroundStyle(.black)

                        
                    }
                    .frame(width: geometry.size.width, height: viewAppears ? geometry.size.height * 0.3 : geometry.size.height * 0.6)
                    .scaleEffect(buttonSize)
                    .onLongPressGesture(minimumDuration: 0.5, perform: {
                        aboutToShowWelcomeScreen = false
                        viewModel.requestNotificationPermissions()
                        dismiss()
                        
                        print("WelcomeScreen has been seen.")
                    }) { Bool in
                        if Bool {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                buttonColor = .yellow
                                buttonSize = 0.9
                            }
                            
                            // Overlay Animation
                            withAnimation(.easeIn(duration: 0.6)) {
                                overlaySize += 3.0
                            }
                            
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                buttonColor = .orange
                                buttonSize = 1.0
                            }
                            
                            // Overlay Animation
                            withAnimation(.easeOut(duration: 0.3)) {
                                overlaySize = 0.0
                            }
                        }
                    }
                }
                
                
            }
            .onAppear {
                withAnimation(.bouncy(duration: 1.5)) {
                    viewAppears = true
                    
                }
            }
            .foregroundStyle(.white)
            .lineLimit(4)
            .minimumScaleFactor(0.2)
        }
    }
}





#Preview {
    WelcomeScreen(viewModel: TimerViewModel())
}
