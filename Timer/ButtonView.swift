//
//  ButtonView.swift
//  Timer
//
//  Created by Kristian Emil on 15/09/2024.
//

import SwiftUI
import Foundation
import QuartzCore

struct ButtonView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var buttonColor: Color = .yellow
    @State private var buttonSize: Double = 1.0
    @State private var overlaySize: Double = 0.0
    
    var body: some View {
        // Start/Stop Button
        GeometryReader(content: { geometry in
            ZStack {
                if viewModel.isPaused {
                    Rectangle()
                        .fill(buttonColor)
                        .overlay {
                            Circle()
                                .foregroundStyle(.white.opacity(0.2))
                                .allowsHitTesting(false)
                                .scaleEffect(overlaySize, anchor: .center)
                            
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 25))

                } else {
                    Rectangle()
                        .fill(viewModel.isRunning ? Color.red : Color.black)
                        .overlay {
                            Circle()
                                .foregroundStyle(.white.opacity(0.2))
                                .allowsHitTesting(false)
                                .scaleEffect(overlaySize, anchor: .center)
                            
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                
                VStack {
                    Spacer()
                    ZStack {
                        
                        if viewModel.isPaused {
                            
                            if viewModel.isPaused && viewModel.currentTime == 0 {
                                VStack {
                                    // Large text
                                    Text("Ended")
                                        .padding()
                                    
                                    // Small text
                                    Text("Hold to reset")
                                        .font(.footnote)
                                        .bold()
                                }
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                            } else {
                                Text("Resume")
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.3)
                                    .padding()
                            }
                            
                        } else {
                            Text(viewModel.isRunning ? "Stop" : "Start")
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                                .padding()
                        }
                    }
                    .font(.custom("Stormfaze", size: 46))
                    .padding(.bottom)
                    
                    Spacer()
                }
            }
            .scaleEffect(buttonSize, anchor: .center)
            .overlay {
                // Create a smaller tapable area, to remove mistaps!
                Rectangle()
                    .foregroundStyle(.clear)
                    .contentShape(Rectangle())
                    .cornerRadius(25)
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.8)
                    .onTapGesture {
                        if viewModel.isRunning {
                            viewModel.stopTimer()
                        } else {
                            viewModel.startTimer()
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5, perform: viewModel.resetTime) { Bool in
                            if Bool {
                                
                            withAnimation(.easeInOut(duration: 0.1)) {
                                buttonColor = .orange
                                buttonSize = 0.9
                                print("Pressing!")
                            }
                                // Overlay Animation
                                withAnimation(.easeIn(duration: 0.6)) {
                                    overlaySize += 3.0
                                }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                buttonColor = .yellow
                                buttonSize = 1.0
                                overlaySize -= 2.0
                                print("Not pressing.")
                            }
                            // Overlay Animation
                            withAnimation(.easeOut(duration: 0.3)) {
                                overlaySize = 0.0
                            }
                        }
                        
                            
                    }
            }
        })
        .ignoresSafeArea()
    }
}

#Preview {
    ButtonView(viewModel: TimerViewModel())
}
