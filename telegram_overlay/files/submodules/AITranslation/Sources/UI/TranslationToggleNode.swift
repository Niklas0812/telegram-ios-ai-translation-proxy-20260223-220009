import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
public final class TranslationToggleNode: UIButton {
    public var isTranslationEnabled: Bool = false {
        didSet { updateAppearance() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("AI", for: .normal)
        layer.cornerRadius = 8
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setTitle("AI", for: .normal)
        updateAppearance()
    }

    private func updateAppearance() {
        backgroundColor = isTranslationEnabled ? UIColor.systemBlue : UIColor.systemGray4
        setTitleColor(.white, for: .normal)
        accessibilityLabel = isTranslationEnabled ? "AI Translation On" : "AI Translation Off"
    }
}
#endif
