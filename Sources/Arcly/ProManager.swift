import Foundation
import StoreKit

@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()

    static let productID = "com.qingshan.orbis.pro"
    private static let localProUnlocked = true

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Published var isPro: Bool = false
    @Published var product: Product? = nil
    @Published var purchaseInProgress: Bool = false
    @Published var loadState: LoadState = .loading

    private var transactionListener: Task<Void, Never>?

    init() {
        if Self.localProUnlocked {
            setPro(true)
            product = nil
            purchaseInProgress = false
            loadState = .loaded
            return
        }

        isPro = UserDefaults.standard.bool(forKey: "isPro")
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await verifyPurchase() }

        #if DEBUG
        // 仅 Debug 构建：强制解锁 Pro，方便截图与本地开发。
        // Release 构建（上架包）不受影响。
        setPro(true)
        #endif
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 加载商品信息

    func loadProduct() async {
        guard !Self.localProUnlocked else {
            loadState = .loaded
            return
        }

        loadState = .loading

        let loadTask = Task { try await Product.products(for: [Self.productID]) }
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            loadTask.cancel()
        }

        do {
            let products = try await loadTask.value
            timeoutTask.cancel()
            if let first = products.first {
                product = first
                loadState = .loaded
            } else {
                product = nil
                loadState = .failed(Loc.string("pro.productUnavailable"))
            }
        } catch is CancellationError {
            product = nil
            loadState = .failed(Loc.string("pro.loadingTimeout"))
        } catch {
            product = nil
            loadState = .failed(error.localizedDescription)
            NSLog("❌ 加载商品失败: %@", error.localizedDescription)
        }
    }

    // MARK: - 购买

    func purchase() async {
        guard !Self.localProUnlocked else {
            setPro(true)
            return
        }

        guard let product = product, !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    await transaction.finish()
                    setPro(true)
                }
            case .pending:
                NSLog("⏳ 购买等待审核")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            NSLog("❌ 购买失败: %@", error.localizedDescription)
        }
    }

    // MARK: - 恢复购买

    func restore() async {
        guard !Self.localProUnlocked else {
            setPro(true)
            return
        }

        try? await AppStore.sync()
        await verifyPurchase()
    }

    // MARK: - 验证购买状态

    func verifyPurchase() async {
        guard !Self.localProUnlocked else {
            setPro(true)
            return
        }

        #if DEBUG
        // Debug 构建：始终视为 Pro（见 init 中的说明）。
        setPro(true)
        return
        #else
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                setPro(true)
                return
            }
        }
        // 没有有效购买记录
        setPro(false)
        #endif
    }

    // MARK: - 监听交易更新

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    if transaction.productID == Self.productID {
                        await MainActor.run {
                            self.setPro(transaction.revocationDate == nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 状态持久化

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "isPro")
    }

    // MARK: - 功能门控

    var maxSlots: Int { isPro ? 12 : 6 }
    var canAddFolder: Bool { isPro }
    var canCustomizeSize: Bool { isPro }
    var canControlMusic: Bool { isPro }
}
