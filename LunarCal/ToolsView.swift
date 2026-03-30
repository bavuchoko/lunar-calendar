import SwiftUI
import CoreData

struct ToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var message: String?
    @State private var showMessage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        Text("도구")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .padding(.top, 10)

                        Text("광고 제거")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                    }

                    Button {
                        Task { await purchaseManager.purchaseRemoveAds() }
                    } label: {
                        Text(purchaseManager.isAdsRemoved ? "이미 광고가 제거되어 있어요" : "광고 제거 구매")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(purchaseButtonBackground)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
                    }
                    .padding(.horizontal, 22)
                    .disabled(purchaseManager.isAdsRemoved || purchaseManager.isBusy)
                    .opacity(purchaseManager.isAdsRemoved ? 0.55 : 1.0)

                    Button {
                        Task { await purchaseManager.restorePurchases() }
                    } label: {
                        Text("구매 복원")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .disabled(purchaseManager.isBusy)

                    Text("“광고 제거 구매”는 스토어 인앱 결제로 진행됩니다.\n“구매 복원”은 재설치/기기 변경 후 구매 내역을 불러옵니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 4)

                    Divider()
                        .padding(.horizontal, 22)
                        .padding(.top, 10)

                    VStack(spacing: 12) {
                        Text("iCloud 백업")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            do {
                                try ICloudBackupManager.shared.backupToICloud(viewContext: viewContext)
                                show("백업이 완료됐어요.")
                            } catch {
                                show(error.localizedDescription)
                            }
                        } label: {
                            Text("iCloud에 백업")
                                .font(.system(size: 16, weight: .semibold))
//                                .foregroundColor(.white)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
//                                .background(Color.black.opacity(0.86))
                                .background(Color(UIColor.systemGray6))
                                .clipShape(Capsule())
                        }

                        Button {
                            do {
                                try ICloudBackupManager.shared.restoreFromICloud(viewContext: viewContext)
                                show("복원이 완료됐어요. 앱을 다시 열면 반영이 확실해요.")
                            } catch {
                                show(error.localizedDescription)
                            }
                        } label: {
                            Text("iCloud에서 복원")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onReceive(purchaseManager.$lastErrorMessage) { err in
                guard let err else { return }
                show(err)
                purchaseManager.clearError()
            }
            .alert("안내", isPresented: $showMessage) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var purchaseButtonBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 14/255, green: 23/255, blue: 40/255),
                Color(red: 8/255, green: 14/255, blue: 28/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func show(_ text: String) {
        message = text
        showMessage = true
    }
}

