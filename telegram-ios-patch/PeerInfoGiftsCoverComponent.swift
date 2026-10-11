import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import AnimationCache
import MultiAnimationRenderer
import TelegramCore
import AccountContext
import SwiftSignalKit
import EmojiTextAttachmentView
import LokiRng
import TextFormat
import HierarchyTrackingLayer
import AVFoundation

public final class PeerInfoGiftsCoverComponent: Component {
    public let context: AccountContext
    public let peerId: EnginePeer.Id
    public let giftsContext: ProfileGiftsContext
    public let hasBackground: Bool
    public let avatarCenter: CGPoint
    public let avatarSize: CGSize
    public let defaultHeight: CGFloat
    public let avatarTransitionFraction: CGFloat
    public let statusBarHeight: CGFloat
    public let topLeftButtonsSize: CGSize
    public let topRightButtonsSize: CGSize
    public let titleWidth: CGFloat
    public let bottomHeight: CGFloat
    public let islandCenter: CGPoint?
    public let hideStyle: GiftHideStyle
    public let action: (ProfileGiftsContext.State.StarGift) -> Void

    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        giftsContext: ProfileGiftsContext,
        hasBackground: Bool,
        avatarCenter: CGPoint,
        avatarSize: CGSize,
        defaultHeight: CGFloat,
        avatarTransitionFraction: CGFloat,
        statusBarHeight: CGFloat,
        topLeftButtonsSize: CGSize,
        topRightButtonsSize: CGSize,
        titleWidth: CGFloat,
        bottomHeight: CGFloat,
        islandCenter: CGPoint? = nil,
        hideStyle: GiftHideStyle = GiftHideStyle.current,
        action: @escaping (ProfileGiftsContext.State.StarGift) -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.giftsContext = giftsContext
        self.hasBackground = hasBackground
        self.avatarCenter = avatarCenter
        self.avatarSize = avatarSize
        self.defaultHeight = defaultHeight
        self.avatarTransitionFraction = avatarTransitionFraction
        self.statusBarHeight = statusBarHeight
        self.topLeftButtonsSize = topLeftButtonsSize
        self.topRightButtonsSize = topRightButtonsSize
        self.titleWidth = titleWidth
        self.bottomHeight = bottomHeight
        self.islandCenter = islandCenter
        self.hideStyle = hideStyle
        self.action = action
    }
    
    public static func ==(lhs: PeerInfoGiftsCoverComponent, rhs: PeerInfoGiftsCoverComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.hasBackground != rhs.hasBackground {
            return false
        }
        if lhs.avatarCenter != rhs.avatarCenter {
            return false
        }
        if lhs.avatarSize != rhs.avatarSize {
            return false
        }
        if lhs.defaultHeight != rhs.defaultHeight {
            return false
        }
        if lhs.avatarTransitionFraction != rhs.avatarTransitionFraction {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
            return false
        }
        if lhs.topLeftButtonsSize != rhs.topLeftButtonsSize {
            return false
        }
        if lhs.topRightButtonsSize != rhs.topRightButtonsSize {
            return false
        }
        if lhs.titleWidth != rhs.titleWidth {
            return false
        }
        if lhs.bottomHeight != rhs.bottomHeight {
            return false
        }
        if lhs.islandCenter != rhs.islandCenter {
            return false
        }
        if lhs.hideStyle != rhs.hideStyle {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var currentSize: CGSize?
        private var component: PeerInfoGiftsCoverComponent?
        private var state: EmptyComponentState?
                
        private var giftsDisposable: Disposable?
        private var gifts: [ProfileGiftsContext.State.StarGift] = []
        private var appliedGiftIds: [Int64] = []
        
        private var iconLayers: [AnyHashable: GiftIconLayer] = [:]
        private var iconPositions: [PositionGenerator.Position] = []
        private let seed = UInt(Date().timeIntervalSince1970)
        
        private let trackingLayer = HierarchyTrackingLayer()
        private var isCurrentlyInHierarchy = false

        private let blackHoleLayer = BlackHoleLayer()
        private var dustLayers: [AnyHashable: GiftDustLayer] = [:]
        private let gloveLayer = GiftSnapGloveLayer()
        private var snapTriggered = false

        private var isUpdating = false

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.clipsToBounds = true

            self.layer.addSublayer(self.trackingLayer)
            self.layer.addSublayer(self.blackHoleLayer)
            
            self.trackingLayer.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.isCurrentlyInHierarchy = true
                self.updateAnimations()
            }
            
            self.trackingLayer.didExitHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.isCurrentlyInHierarchy = false
            }
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:))))
        }
        
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.giftsDisposable?.dispose()
        }
        
        @objc private func tapped(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            for (_, iconLayer) in self.iconLayers {
                if iconLayer.frame.contains(location) {
                    component.action(iconLayer.gift)
                    break
                }
            }
        }
        
        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for (_, iconLayer) in self.iconLayers {
                if iconLayer.frame.contains(point) {
                    return true
                }
            }
            return false
        }
        
        func updateAnimations() {
            var index = 0
            for (_, iconLayer) in self.iconLayers {
                if self.isCurrentlyInHierarchy {
                    iconLayer.startAnimations(index: index)
                }
                index += 1
            }
        }
        
        private var scheduledAnimateIn = false
        public func willAnimateIn() {
            self.scheduledAnimateIn = true
            for (_, layer) in self.iconLayers {
                layer.opacity = 0.0
            }
        }
        
        public func animateIn() {
            guard let _ = self.currentSize, let component = self.component else {
                return
            }
            self.scheduledAnimateIn = false
            
            for (_, layer) in self.iconLayers {
                layer.opacity = 1.0
                layer.animatePosition(
                    from: component.islandCenter ?? component.avatarCenter,
                    to: layer.position,
                    duration: 0.4,
                    timingFunction: kCAMediaTimingFunctionSpring
                )
            }
        }
    
        func update(component: PeerInfoGiftsCoverComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let previousCurrentSize = self.currentSize
            self.currentSize = availableSize
                    
            let iconSize = CGSize(width: 32.0, height: 32.0)
            
            let giftIds = self.gifts.map { gift in
                if case let .unique(gift) = gift.gift {
                    return gift.id
                } else {
                    return 0
                }
            }
            
            if !giftIds.isEmpty && (self.iconPositions.isEmpty || previousCurrentSize?.width != availableSize.width || (previousComponent != nil && previousComponent?.hasBackground != component.hasBackground) || self.appliedGiftIds != giftIds) {
                var avatarCenter = component.avatarCenter
                if avatarCenter.y < 0.0 {
                    avatarCenter.y = component.statusBarHeight + 75.0
                }
                
                var excludeRects: [CGRect] = []
                if component.statusBarHeight > 0.0 {
                    excludeRects.append(CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: component.statusBarHeight + 4.0)))
                }
                excludeRects.append(CGRect(origin: CGPoint(x: 0.0, y: component.statusBarHeight), size: component.topLeftButtonsSize))
                excludeRects.append(CGRect(origin: CGPoint(x: availableSize.width - component.topRightButtonsSize.width, y: component.statusBarHeight), size: component.topRightButtonsSize))
                excludeRects.append(CGRect(origin: CGPoint(x: floor((availableSize.width - component.titleWidth) / 2.0), y: avatarCenter.y + component.avatarSize.height / 2.0 + 6.0), size: CGSize(width: component.titleWidth, height: 100.0)))
                if component.bottomHeight > 0.0 {
                    excludeRects.append(CGRect(origin: CGPoint(x: 0.0, y: component.defaultHeight - component.bottomHeight), size: CGSize(width: availableSize.width, height: component.bottomHeight)))
                }
                                                
                let positionGenerator = PositionGenerator(
                    containerSize: CGSize(width: availableSize.width, height: component.defaultHeight),
                    centerFrame: component.avatarSize.centered(around: avatarCenter),
                    exclusionZones: excludeRects,
                    minimumDistance: 42.0,
                    edgePadding: 5.0,
                    seed: self.seed
                )
                
                self.iconPositions = positionGenerator.generatePositions(count: 12, itemSize: iconSize)
            }
            self.appliedGiftIds = giftIds
            
            if self.giftsDisposable == nil {
                self.giftsDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    component.giftsContext.state,
                    component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId))
                    |> map { peer -> Int64? in
                        if case let .user(user) = peer, case let .starGift(id, _, _, _, _, _, _, _, _) = user.emojiStatus?.content {
                            return id
                        }
                        return nil
                    }
                    |> distinctUntilChanged
                ).start(next: { [weak self] state, giftStatusId in
                    guard let self else {
                        return
                    }
                    
                    let pinnedGifts = state.gifts.filter { gift in
                        if gift.pinnedToTop {
                            if case let .unique(uniqueGift) = gift.gift {
                                return uniqueGift.id != giftStatusId
                            }
                        }
                        return false
                    }
                    self.gifts = pinnedGifts
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                })
            }
                                                                          
            var validIds = Set<AnyHashable>()
            var placedGifts: [(point: CGPoint, radius: CGFloat)] = []
            var index = 0
            for gift in self.gifts.prefix(12) {
                guard index < self.iconPositions.count else {
                    break
                }
                let id: AnyHashable
                if case let .unique(uniqueGift) = gift.gift {
                    id = uniqueGift.slug
                } else {
                    id = index
                }
                validIds.insert(id)
                
                var iconTransition = transition
                let iconPosition = self.iconPositions[index]
                let iconLayer: GiftIconLayer
                if let current = self.iconLayers[id] {
                    iconLayer = current
                } else {
                    iconTransition = .immediate
                    iconLayer = GiftIconLayer(context: component.context, gift: gift, size: iconSize, glowing: component.hasBackground)
                    self.iconLayers[id] = iconLayer
                    self.layer.addSublayer(iconLayer)
                    
                    if self.scheduledAnimateIn {
                        iconLayer.opacity = 0.0
                    } else {
                        iconLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        iconLayer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    }
                    
                    iconLayer.startAnimations(index: index)
                }
                iconLayer.glowing = component.hasBackground
                
                let itemDistanceFraction = max(0.0, min(0.5, (iconPosition.distance - component.avatarSize.width / 2.0) / 144.0))
                let itemScaleFraction = patternScaleValueAt(fraction: min(1.0, component.avatarTransitionFraction * 1.33), t: itemDistanceFraction, reverse: false)
               
                func interpolatePosition(from: PositionGenerator.Position, to: PositionGenerator.Position, t: CGFloat) -> PositionGenerator.Position {
                    let clampedT = max(0, min(1, t))
                    
                    let interpolatedDistance = from.distance + (to.distance - from.distance) * clampedT
                    let interpolatedAngle = from.angle + (to.angle - from.angle) * clampedT
                    
                    return PositionGenerator.Position(distance: interpolatedDistance, angle: interpolatedAngle, scale: from.scale)
                }
                
                let toAngle: CGFloat = .pi * 0.18
                let centerPosition = PositionGenerator.Position(distance: 0.0, angle: iconPosition.angle + toAngle, scale: iconPosition.scale)
                let effectivePosition = interpolatePosition(from: iconPosition, to: centerPosition, t: itemScaleFraction)
                let effectiveAngle = toAngle * itemScaleFraction
                
                var absolutePosition = getAbsolutePosition(position: effectivePosition, centerPoint: component.avatarCenter)
                var resultAngle = effectiveAngle
                var resultScale = iconPosition.scale * (1.0 - itemScaleFraction)
                var resultAlpha = 1.0 - itemScaleFraction

                if let islandCenter = component.islandCenter {
                    let homePoint = getAbsolutePosition(position: iconPosition, centerPoint: component.avatarCenter)
                    let dx = homePoint.x - islandCenter.x
                    let dy = homePoint.y - islandCenter.y
                    let startDistance = sqrt(dx * dx + dy * dy)
                    let startAngle = atan2(dy, dx)
                    let fraction = itemScaleFraction
                    let pull = fraction * fraction * fraction

                    switch component.hideStyle {
                    case .blackHole:
                        // Spiral into the island while spinning: slow start, fast finish.
                        let spin: CGFloat = .pi * 1.9
                        let spiralAngle = startAngle + spin * pow(fraction, 1.8)
                        let spiralDistance = startDistance * (1.0 - pull)
                        absolutePosition = CGPoint(
                            x: islandCenter.x + spiralDistance * cos(spiralAngle),
                            y: islandCenter.y + spiralDistance * sin(spiralAngle)
                        )
                        resultAngle = spin * fraction * 0.35
                        resultScale = iconPosition.scale * (1.0 - 0.82 * pull)
                        resultAlpha = fraction > 0.88 ? max(0.0, (1.0 - fraction) / 0.12) : 1.0
                    case .straight:
                        // Straight line into the island, no spin.
                        let distance = startDistance * (1.0 - pull)
                        absolutePosition = CGPoint(
                            x: islandCenter.x + distance * cos(startAngle),
                            y: islandCenter.y + distance * sin(startAngle)
                        )
                        resultAngle = 0.0
                        resultScale = iconPosition.scale * (1.0 - 0.82 * pull)
                        resultAlpha = fraction > 0.88 ? max(0.0, (1.0 - fraction) / 0.12) : 1.0
                    case .disintegrate:
                        // Gifts stay in place, drift slightly and fade out while dust flies away.
                        absolutePosition = CGPoint(x: homePoint.x + 14.0 * fraction, y: homePoint.y - 10.0 * fraction)
                        resultAngle = 0.0
                        resultScale = iconPosition.scale * (1.0 - 0.15 * fraction)
                        resultAlpha = max(0.0, 1.0 - 3.2 * fraction)

                        if fraction > 0.02 {
                            let dust: GiftDustLayer
                            if let current = self.dustLayers[id] {
                                dust = current
                            } else {
                                dust = GiftDustLayer()
                                self.dustLayers[id] = dust
                                self.layer.addSublayer(dust)
                                dust.burst()
                            }
                            dust.position = absolutePosition
                        } else if let dust = self.dustLayers.removeValue(forKey: id) {
                            dust.removeFromSuperlayer()
                        }
                    }
                }

                // Soft-body spacing: a gift never sits on top of an earlier one, it is pushed out along the contact line.
                // This is stateless (derived from the layout every pass), so it never jitters.
                let giftRadius = iconSize.width * 0.5 * resultScale * 1.15
                for other in placedGifts {
                    let ddx = absolutePosition.x - other.point.x
                    let ddy = absolutePosition.y - other.point.y
                    let distance = max(0.001, sqrt(ddx * ddx + ddy * ddy))
                    let minDistance = giftRadius + other.radius + 4.0
                    if distance < minDistance {
                        let push = minDistance - distance
                        absolutePosition = CGPoint(x: absolutePosition.x + ddx / distance * push, y: absolutePosition.y + ddy / distance * push)
                    }
                }
                if resultAlpha > 0.05 {
                    placedGifts.append((absolutePosition, giftRadius))
                }

                iconTransition.setBounds(layer: iconLayer, bounds: CGRect(origin: .zero, size: iconSize))
                iconTransition.setPosition(layer: iconLayer, position: absolutePosition)
                iconLayer.updateRotation(resultAngle, transition: iconTransition)
                iconTransition.setScale(layer: iconLayer, scale: resultScale)

                if !self.scheduledAnimateIn {
                    iconTransition.setAlpha(layer: iconLayer, alpha: resultAlpha)
                }
                
                index += 1
            }

            // Snap glove (disintegrate style only): appears next to the avatar and snaps once when gifts start to hide.
            let hideFraction = min(1.0, component.avatarTransitionFraction * 1.33)
            if component.hideStyle == .disintegrate, component.islandCenter != nil, !self.gifts.isEmpty {
                self.gloveLayer.position = CGPoint(x: component.avatarCenter.x + component.avatarSize.width * 0.5 + 58.0, y: component.avatarCenter.y + 10.0)
                if hideFraction > 0.02 && !self.snapTriggered {
                    self.snapTriggered = true
                    if self.gloveLayer.superlayer == nil {
                        self.layer.addSublayer(self.gloveLayer)
                    }
                    self.gloveLayer.snap()
                } else if hideFraction <= 0.001 && self.snapTriggered {
                    self.snapTriggered = false
                    self.gloveLayer.hide()
                }
            } else if self.snapTriggered {
                self.snapTriggered = false
                self.gloveLayer.removeFromSuperlayer()
            }

            if component.hideStyle != .disintegrate, !self.dustLayers.isEmpty {
                for (_, dust) in self.dustLayers {
                    dust.removeFromSuperlayer()
                }
                self.dustLayers.removeAll()
            }

            if let islandCenter = component.islandCenter, !self.gifts.isEmpty, component.hideStyle != .disintegrate {
                let intensity: CGFloat = component.hideStyle == .blackHole ? 1.0 : 0.45
                self.blackHoleLayer.update(center: islandCenter, fraction: min(1.0, component.avatarTransitionFraction * 1.33) * intensity, transition: transition)
            } else {
                self.blackHoleLayer.update(center: component.islandCenter ?? .zero, fraction: 0.0, transition: transition)
            }

            var removeIds: [AnyHashable] = []
            for (id, layer) in self.iconLayers {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        layer.removeFromSuperlayer()
                    })
                }
            }
            for id in removeIds {
                self.iconLayers.removeValue(forKey: id)
            }
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private var shadowImage: UIImage? = {
    return generateImage(CGSize(width: 44.0, height: 44.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.3, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.65).cgColor, UIColor(rgb: 0xffffff, alpha: 0.65).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2.0, y: size.height / 2.0), startRadius: 0.0, endCenter: CGPoint(x: size.width / 2.0, y: size.height / 2.0), endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
    })
}()

private let blackHoleGlowImage: UIImage? = {
    return generateImage(CGSize(width: 250.0, height: 250.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))

        var locations: [CGFloat] = [0.0, 0.35, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xff964f, alpha: 0.42).cgColor, UIColor(rgb: 0xff4fa0, alpha: 0.16).cgColor, UIColor(rgb: 0xff4fa0, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
    })
}()

private let blackHoleRingMaskImage: UIImage? = {
    return generateImage(CGSize(width: 250.0, height: 250.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))

        var locations: [CGFloat] = [0.0, 0.40, 0.54, 0.62, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
    })
}()

public enum GiftHideStyle: Int {
    case blackHole = 0
    case straight = 1
    case disintegrate = 2

    private static let defaultsKey = "bhGiftHideStyle"

    public static var current: GiftHideStyle {
        get {
            return GiftHideStyle(rawValue: UserDefaults.standard.integer(forKey: GiftHideStyle.defaultsKey)) ?? .blackHole
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: GiftHideStyle.defaultsKey)
        }
    }
}

private let giftDustImage: UIImage? = {
    return generateImage(CGSize(width: 6.0, height: 6.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
    })
}()

// One-shot burst of dust particles used by the "disintegrate" hide style.
private final class GiftDustLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()

    override init() {
        super.init()

        self.emitterLayer.emitterShape = .rectangle
        self.emitterLayer.emitterSize = CGSize(width: 30.0, height: 30.0)
        self.emitterLayer.renderMode = .additive
        self.emitterLayer.birthRate = 0.0

        let cell = CAEmitterCell()
        cell.contents = giftDustImage?.cgImage
        cell.birthRate = 90.0
        cell.lifetime = 1.1
        cell.lifetimeRange = 0.4
        cell.velocity = 55.0
        cell.velocityRange = 35.0
        cell.emissionLongitude = -.pi / 4.0
        cell.emissionRange = .pi / 2.0
        cell.yAcceleration = -25.0
        cell.scale = 0.5
        cell.scaleRange = 0.35
        cell.scaleSpeed = -0.35
        cell.alphaSpeed = -0.9
        cell.color = UIColor(rgb: 0xd9dde6).cgColor
        self.emitterLayer.emitterCells = [cell]

        self.addSublayer(self.emitterLayer)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func burst() {
        self.emitterLayer.beginTime = CACurrentMediaTime()
        self.emitterLayer.birthRate = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.emitterLayer.birthRate = 0.0
        }
    }
}

// Small procedural sound for the snap: a low thump plus a short noise burst, generated in memory (no audio asset).
private let giftSnapSoundPlayer: AVAudioPlayer? = {
    let sampleRate = 22050.0
    let count = Int(sampleRate * 0.28)
    var pcm = [Int16](repeating: 0, count: count)
    var seed: UInt32 = 12345
    for i in 0 ..< count {
        let t = Double(i) / sampleRate
        seed = seed &* 1664525 &+ 1013904223
        let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
        let click = noise * exp(-t * 70.0) * 0.8
        let thump = sin(2.0 * Double.pi * (150.0 - 90.0 * t) * t) * exp(-t * 16.0) * 0.7
        pcm[i] = Int16(max(-1.0, min(1.0, click + thump)) * 30000.0)
    }
    var data = Data()
    func append32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func append16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    data.append("RIFF".data(using: .ascii)!); append32(UInt32(36 + count * 2)); data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); append32(16); append16(1); append16(1); append32(UInt32(sampleRate)); append32(UInt32(sampleRate) * 2); append16(2); append16(16)
    data.append("data".data(using: .ascii)!); append32(UInt32(count * 2))
    pcm.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
    let player = try? AVAudioPlayer(data: data)
    player?.prepareToPlay()
    return player
}()

// Simplified silver glove drawn with shape layers: palm, three fingers, and a thumb + index that pinch and snap.
private final class GiftSnapGloveLayer: SimpleLayer {
    private let palm = CAShapeLayer()
    private let fingers: [CAShapeLayer]
    private let thumb = CAShapeLayer()
    private let index = CAShapeLayer()
    private let flash = SimpleLayer()

    override init() {
        func finger(_ rect: CGRect) -> CAShapeLayer {
            let l = CAShapeLayer()
            l.path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2.0).cgPath
            l.fillColor = UIColor(rgb: 0xcfd3dc).cgColor
            l.strokeColor = UIColor(rgb: 0x8b93a3).cgColor
            l.lineWidth = 1.0
            return l
        }
        self.fingers = [
            finger(CGRect(x: 30.0, y: 0.0, width: 11.0, height: 36.0)),
            finger(CGRect(x: 43.0, y: 4.0, width: 11.0, height: 33.0)),
            finger(CGRect(x: 56.0, y: 10.0, width: 10.0, height: 28.0))
        ]
        super.init()

        self.bounds = CGRect(x: 0.0, y: 0.0, width: 80.0, height: 100.0)
        self.opacity = 0.0

        self.palm.path = UIBezierPath(roundedRect: CGRect(x: 24.0, y: 32.0, width: 44.0, height: 44.0), cornerRadius: 14.0).cgPath
        self.palm.fillColor = UIColor(rgb: 0xdfe3ea).cgColor
        self.palm.strokeColor = UIColor(rgb: 0x8b93a3).cgColor
        self.palm.lineWidth = 1.0
        self.addSublayer(self.palm)
        for f in self.fingers { self.addSublayer(f) }

        // Index finger and thumb pivot at their bases so they can bend toward each other.
        self.index.path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 11.0, height: 34.0), cornerRadius: 5.5).cgPath
        self.index.fillColor = UIColor(rgb: 0xcfd3dc).cgColor
        self.index.strokeColor = UIColor(rgb: 0x8b93a3).cgColor
        self.index.lineWidth = 1.0
        self.index.bounds = CGRect(x: 0.0, y: 0.0, width: 11.0, height: 34.0)
        self.index.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        self.index.position = CGPoint(x: 35.0, y: 40.0)
        self.addSublayer(self.index)

        self.thumb.path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 12.0, height: 30.0), cornerRadius: 6.0).cgPath
        self.thumb.fillColor = UIColor(rgb: 0xcfd3dc).cgColor
        self.thumb.strokeColor = UIColor(rgb: 0x8b93a3).cgColor
        self.thumb.lineWidth = 1.0
        self.thumb.bounds = CGRect(x: 0.0, y: 0.0, width: 12.0, height: 30.0)
        self.thumb.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        self.thumb.position = CGPoint(x: 26.0, y: 70.0)
        self.thumb.transform = CATransform3DMakeRotation(-.pi * 0.45, 0.0, 0.0, 1.0)
        self.addSublayer(self.thumb)

        self.flash.bounds = CGRect(x: 0.0, y: 0.0, width: 28.0, height: 28.0)
        self.flash.position = CGPoint(x: 30.0, y: 36.0)
        self.flash.cornerRadius = 14.0
        self.flash.backgroundColor = UIColor.white.cgColor
        self.flash.opacity = 0.0
        self.addSublayer(self.flash)
    }

    override init(layer: Any) {
        self.fingers = []
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func snap() {
        self.removeAllAnimations()
        self.opacity = 1.0
        self.animateScale(from: 0.6, to: 1.0, duration: 0.25)
        self.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)

        // Pinch: thumb swings in and the index bends toward it, then both release.
        let pinch = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        pinch.values = [-CGFloat.pi * 0.45, -CGFloat.pi * 0.08, -CGFloat.pi * 0.08, -CGFloat.pi * 0.5]
        pinch.keyTimes = [0.0, 0.42, 0.55, 1.0]
        pinch.duration = 0.5
        pinch.beginTime = CACurrentMediaTime() + 0.2
        pinch.fillMode = .backwards
        self.thumb.add(pinch, forKey: "pinch")

        let bend = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        bend.values = [0.0, -CGFloat.pi * 0.4, -CGFloat.pi * 0.4, 0.05]
        bend.keyTimes = [0.0, 0.42, 0.55, 1.0]
        bend.duration = 0.5
        bend.beginTime = CACurrentMediaTime() + 0.2
        bend.fillMode = .backwards
        self.index.add(bend, forKey: "bend")

        let flashAnimation = CAKeyframeAnimation(keyPath: "opacity")
        flashAnimation.values = [0.0, 0.0, 0.95, 0.0]
        flashAnimation.keyTimes = [0.0, 0.5, 0.58, 1.0]
        flashAnimation.duration = 0.7
        flashAnimation.beginTime = CACurrentMediaTime() + 0.2
        self.flash.add(flashAnimation, forKey: "flash")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + 0.5 * 0.5) {
            giftSnapSoundPlayer?.currentTime = 0.0
            giftSnapSoundPlayer?.play()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    func hide() {
        self.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak self] _ in
            self?.opacity = 0.0
            self?.removeFromSuperlayer()
        })
    }
}

private final class BlackHoleLayer: SimpleLayer {
    private let diameter: CGFloat = 250.0
    private let glowLayer = SimpleLayer()
    private let ringLayer = CAGradientLayer()
    private let ringMaskLayer = SimpleLayer()

    override init() {
        super.init()

        self.opacity = 0.0

        self.glowLayer.contents = blackHoleGlowImage?.cgImage

        self.ringLayer.type = .conic
        self.ringLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.ringLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        self.ringLayer.colors = [
            UIColor(rgb: 0xffb86b, alpha: 0.0).cgColor,
            UIColor(rgb: 0xffb86b, alpha: 1.0).cgColor,
            UIColor(rgb: 0xff4fa0, alpha: 1.0).cgColor,
            UIColor(rgb: 0x5b8cff, alpha: 0.0).cgColor,
            UIColor(rgb: 0x5b8cff, alpha: 1.0).cgColor,
            UIColor(rgb: 0x7be0ff, alpha: 1.0).cgColor,
            UIColor(rgb: 0xffb86b, alpha: 0.0).cgColor
        ]
        self.ringLayer.locations = [0.0, 0.14, 0.33, 0.47, 0.64, 0.80, 1.0]
        self.ringMaskLayer.contents = blackHoleRingMaskImage?.cgImage
        self.ringLayer.mask = self.ringMaskLayer

        self.addSublayer(self.glowLayer)
        self.addSublayer(self.ringLayer)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(center: CGPoint, fraction: CGFloat, transition: ComponentTransition) {
        let fraction = max(0.0, min(1.0, fraction))

        let bounds = CGRect(origin: .zero, size: CGSize(width: self.diameter, height: self.diameter))
        self.bounds = bounds
        self.position = center
        self.glowLayer.frame = bounds
        self.ringLayer.frame = bounds
        self.ringMaskLayer.frame = bounds

        // The disc is squashed vertically so it reads as an accretion disc seen at an angle.
        let scale = 0.6 + 0.5 * fraction
        self.transform = CATransform3DMakeScale(scale, scale * 0.42, 1.0)
        transition.setAlpha(layer: self, alpha: fraction)

        if self.ringLayer.animation(forKey: "spin") == nil {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0.0
            animation.toValue = CGFloat.pi * 2.0
            animation.duration = 4.0
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            self.ringLayer.add(animation, forKey: "spin")
        }
    }
}

private final class StarsEffectLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(color: UIColor, size: CGSize) {
        self.color = color
        
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 8.0
        emitter.lifetime = 2.0
        emitter.velocity = 0.1
        emitter.scale = (size.width / 40.0) * 0.12
        emitter.scaleRange = 0.02
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.withAlphaComponent(0.58).cgColor,
            color.withAlphaComponent(0.58).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        self.emitterLayer.emitterCells = [emitter]
    }
    
    private var color: UIColor?
        
    func update(color: UIColor, size: CGSize) {
        if self.color != color {
            self.setup(color: color, size: size)
        }
        self.emitterLayer.seed = UInt32.random(in: .min ..< .max)
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = size
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}

private class GiftIconLayer: SimpleLayer {
    private let context: AccountContext
    let gift: ProfileGiftsContext.State.StarGift
    private let size: CGSize
    var glowing: Bool {
        didSet {
            self.shadowLayer.opacity = self.glowing ? 1.0 : 0.0
            
            let color: UIColor
            if self.glowing {
                color = .white
            } else if let layerTintColor = self.shadowLayer.layerTintColor {
                color = UIColor(cgColor: layerTintColor)
            } else {
                color = .white
            }
            
            let side = floor(self.size.width * 1.25)
            let starsFrame = CGSize(width: side, height: side).centered(in: CGRect(origin: .zero, size: self.size))
            self.starsLayer.frame = starsFrame
            self.starsLayer.update(color: color, size: starsFrame.size)
        }
    }
    
    let shadowLayer = SimpleLayer()
    let starsLayer = StarsEffectLayer()
    let animationLayer: InlineStickerItemLayer
    
    override init(layer: Any) {
        guard let layer = layer as? GiftIconLayer else {
            fatalError()
        }
                
        let context = layer.context
        let gift = layer.gift
        let size = layer.size
        let glowing = layer.glowing
        
        var file: TelegramMediaFile?
        var color: UIColor = .white
        switch gift.gift {
        case let .generic(gift):
            file = gift.file
        case let .unique(gift):
            for attribute in gift.attributes {
                if case let .model(_, fileValue, _, _) = attribute {
                    file = fileValue
                } else if case let .backdrop(_, _, innerColor, _, _, _, _) = attribute {
                    color = UIColor(rgb: UInt32(bitPattern: innerColor))
                }
            }
        }
        
        let emoji = ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil,
            fileId: file?.fileId.id ?? 0,
            file: file
        )
        self.animationLayer = InlineStickerItemLayer(
            context: .account(context),
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: emoji,
            file: file,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            unique: true,
            placeholderColor: UIColor.white.withAlphaComponent(0.2),
            pointSize: CGSize(width: size.width * 2.0, height: size.height * 2.0),
            loopCount: 1
        )
        
        self.shadowLayer.contents = shadowImage?.cgImage
        self.shadowLayer.layerTintColor = color.cgColor
        self.shadowLayer.opacity = glowing ? 1.0 : 0.0
        
        self.context = context
        self.gift = gift
        self.size = size
        self.glowing = glowing
        
        super.init()
        
        let side = floor(size.width * 1.25)
        let starsFrame = CGSize(width: side, height: side).centered(in: CGRect(origin: .zero, size: size))
        self.starsLayer.frame = starsFrame
        self.starsLayer.update(color: glowing ? .white : color, size: starsFrame.size)
        
        self.addSublayer(self.shadowLayer)
        self.addSublayer(self.starsLayer)
        self.addSublayer(self.animationLayer)
    }
    
    init(
        context: AccountContext,
        gift: ProfileGiftsContext.State.StarGift,
        size: CGSize,
        glowing: Bool
    ) {
        self.context = context
        self.gift = gift
        self.size = size
        self.glowing = glowing
        
        var file: TelegramMediaFile?
        var color: UIColor = .white
        switch gift.gift {
        case let .generic(gift):
            file = gift.file
        case let .unique(gift):
            for attribute in gift.attributes {
                if case let .model(_, fileValue, _, _) = attribute {
                    file = fileValue
                } else if case let .backdrop(_, _, innerColor, _, _, _, _) = attribute {
                    color = UIColor(rgb: UInt32(bitPattern: innerColor))
                }
            }
        }
        
        let emoji = ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil,
            fileId: file?.fileId.id ?? 0,
            file: file
        )
        self.animationLayer = InlineStickerItemLayer(
            context: .account(context),
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: emoji,
            file: file,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            unique: true,
            placeholderColor: UIColor.white.withAlphaComponent(0.2),
            pointSize: CGSize(width: size.width * 2.0, height: size.height * 2.0),
            loopCount: 1
        )
        
        self.shadowLayer.contents = shadowImage?.cgImage
        self.shadowLayer.layerTintColor = color.cgColor
        self.shadowLayer.opacity = glowing ? 1.0 : 0.0
        
        super.init()
        
        let side = floor(size.width * 1.25)
        let starsFrame = CGSize(width: side, height: side).centered(in: CGRect(origin: .zero, size: size))
        self.starsLayer.frame = starsFrame
        self.starsLayer.update(color: glowing ? .white : color, size: starsFrame.size)
        
        self.addSublayer(self.shadowLayer)
        self.addSublayer(self.starsLayer)
        self.addSublayer(self.animationLayer)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func layoutSublayers() {
        self.shadowLayer.frame = CGRect(origin: .zero, size: self.bounds.size).insetBy(dx: -8.0, dy: -8.0)
        self.animationLayer.bounds = CGRect(origin: .zero, size: self.bounds.size)
        self.animationLayer.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
    }
    
    func updateRotation(_ angle: CGFloat, transition: ComponentTransition) {
        self.animationLayer.transform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0)
    }
    
    func startAnimations(index: Int) {
        let beginTime = Double(index) * 1.5
        
        if self.animation(forKey: "hover") == nil {
            let upDistance = CGFloat.random(in: 1.0 ..< 2.0)
            let downDistance = CGFloat.random(in: 1.0 ..< 2.0)
            let hoverDuration = TimeInterval.random(in: 3.5 ..< 4.5)
            
            let hoverAnimation = CABasicAnimation(keyPath: "transform.translation.y")
            hoverAnimation.duration = hoverDuration
            hoverAnimation.fromValue = -upDistance
            hoverAnimation.toValue = downDistance
            hoverAnimation.autoreverses = true
            hoverAnimation.repeatCount = .infinity
            hoverAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            hoverAnimation.beginTime = beginTime
            hoverAnimation.isAdditive = true
            self.add(hoverAnimation, forKey: "hover")
        }
        
        if self.animationLayer.animation(forKey: "wiggle") == nil {
            let fromRotationAngle = CGFloat.random(in: 0.025 ..< 0.05)
            let toRotationAngle = CGFloat.random(in: 0.025 ..< 0.05)
            let wiggleDuration = TimeInterval.random(in: 2.0 ..< 3.0)
            
            let wiggleAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            wiggleAnimation.duration = wiggleDuration
            wiggleAnimation.fromValue = -fromRotationAngle
            wiggleAnimation.toValue = toRotationAngle
            wiggleAnimation.autoreverses = true
            wiggleAnimation.repeatCount = .infinity
            wiggleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wiggleAnimation.beginTime = beginTime
            wiggleAnimation.isAdditive = true
            self.animationLayer.add(wiggleAnimation, forKey: "wiggle")
        }
        
        if self.shadowLayer.animation(forKey: "glow") == nil {
            let glowDuration = TimeInterval.random(in: 2.0 ..< 3.0)
            
            let glowAnimation = CABasicAnimation(keyPath: "transform.scale")
            glowAnimation.duration = glowDuration
            glowAnimation.fromValue = 1.0
            glowAnimation.toValue = 1.2
            glowAnimation.autoreverses = true
            glowAnimation.repeatCount = .infinity
            glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            glowAnimation.beginTime = beginTime
            self.shadowLayer.add(glowAnimation, forKey: "glow")
        }
    }
}

private struct PositionGenerator {
    struct Position {
        let distance: CGFloat
        let angle: CGFloat
        let scale: CGFloat
        
        var relativeCartesian: CGPoint {
            return CGPoint(
                x: self.distance * cos(self.angle),
                y: self.distance * sin(self.angle)
            )
        }
    }
    
    let containerSize: CGSize
    let centerFrame: CGRect
    let exclusionZones: [CGRect]
    let minimumDistance: CGFloat
    let edgePadding: CGFloat
    let scaleRange: (min: CGFloat, max: CGFloat)
    
    let innerOrbitRange: (min: CGFloat, max: CGFloat)
    let outerOrbitRange: (min: CGFloat, max: CGFloat)
    let innerOrbitCount: Int
    
    private let lokiRng: LokiRng
    
    init(
        containerSize: CGSize,
        centerFrame: CGRect,
        exclusionZones: [CGRect],
        minimumDistance: CGFloat,
        edgePadding: CGFloat,
        seed: UInt,
        scaleRange: (min: CGFloat, max: CGFloat) = (0.7, 1.15),
        innerOrbitRange: (min: CGFloat, max: CGFloat) = (1.4, 2.2),
        outerOrbitRange: (min: CGFloat, max: CGFloat) = (2.5, 3.6),
        innerOrbitCount: Int = 4
    ) {
        self.containerSize = containerSize
        self.centerFrame = centerFrame
        self.exclusionZones = exclusionZones
        self.minimumDistance = minimumDistance
        self.edgePadding = edgePadding
        self.scaleRange = scaleRange
        self.innerOrbitRange = innerOrbitRange
        self.outerOrbitRange = outerOrbitRange
        self.innerOrbitCount = innerOrbitCount
        self.lokiRng = LokiRng(seed0: seed, seed1: 0, seed2: 0)
    }
    
    func generatePositions(count: Int, itemSize: CGSize) -> [Position] {
        var positions: [Position] = []
        
        let centerPoint = CGPoint(x: self.centerFrame.midX, y: self.centerFrame.midY)
        let centerRadius = min(self.centerFrame.width, self.centerFrame.height) / 2.0
        
        let maxAttempts = count * 200
        var attempts = 0
        
        var leftPositions = 0
        var rightPositions = 0
        
        let innerCount = min(self.innerOrbitCount, count)
        
        while positions.count < innerCount && attempts < maxAttempts {
            attempts += 1
            
            let placeOnLeftSide = rightPositions > leftPositions
            
            let orbitRangeSize = self.innerOrbitRange.max - self.innerOrbitRange.min
            let orbitDistanceFactor = self.innerOrbitRange.min + orbitRangeSize * CGFloat(self.lokiRng.next())
            let distance = orbitDistanceFactor * centerRadius
            
            let angleRange: CGFloat = placeOnLeftSide ? .pi : .pi
            let angleOffset: CGFloat = placeOnLeftSide ? .pi/2 : -(.pi/2)
            let angle = angleOffset + angleRange * CGFloat(self.lokiRng.next())
            
            let absolutePosition = getAbsolutePosition(distance: distance, angle: angle, centerPoint: centerPoint)
            
            if absolutePosition.x - itemSize.width/2 < self.edgePadding ||
                absolutePosition.x + itemSize.width/2 > self.containerSize.width - self.edgePadding ||
                absolutePosition.y - itemSize.height/2 < self.edgePadding ||
                absolutePosition.y + itemSize.height/2 > self.containerSize.height - self.edgePadding {
                continue
            }
            
            let itemRect = CGRect(
                x: absolutePosition.x - itemSize.width/2,
                y: absolutePosition.y - itemSize.height/2,
                width: itemSize.width,
                height: itemSize.height
            )
            
            if self.isValidPosition(itemRect, existingPositions: positions.map {
                getAbsolutePosition(distance: $0.distance, angle: $0.angle, centerPoint: centerPoint)
            }, itemSize: itemSize) {
                let scaleRangeSize = max(self.scaleRange.min + 0.1, 0.75) - self.scaleRange.max
                let scale = self.scaleRange.max + scaleRangeSize * CGFloat(self.lokiRng.next())
                positions.append(Position(distance: distance, angle: angle, scale: scale))
                
                if absolutePosition.x < centerPoint.x {
                    leftPositions += 1
                } else {
                    rightPositions += 1
                }
            }
        }
        
        let maxPossibleDistance = hypot(self.containerSize.width, self.containerSize.height) / 2
        
        while positions.count < count && attempts < maxAttempts {
            attempts += 1
            
            let placeOnLeftSide = rightPositions >= leftPositions
            
            let orbitRangeSize = self.outerOrbitRange.max - self.outerOrbitRange.min
            let orbitDistanceFactor = self.outerOrbitRange.min + orbitRangeSize * CGFloat(self.lokiRng.next())
            let distance = orbitDistanceFactor * centerRadius
            
            let angleRange: CGFloat = placeOnLeftSide ? .pi : .pi
            let angleOffset: CGFloat = placeOnLeftSide ? .pi/2 : -(.pi/2)
            let angle = angleOffset + angleRange * CGFloat(self.lokiRng.next())
            
            let absolutePosition = getAbsolutePosition(distance: distance, angle: angle, centerPoint: centerPoint)
            if absolutePosition.x - itemSize.width/2 < self.edgePadding ||
                absolutePosition.x + itemSize.width/2 > self.containerSize.width - self.edgePadding ||
                absolutePosition.y - itemSize.height/2 < self.edgePadding ||
                absolutePosition.y + itemSize.height/2 > self.containerSize.height - self.edgePadding {
                continue
            }
            
            let itemRect = CGRect(
                x: absolutePosition.x - itemSize.width/2,
                y: absolutePosition.y - itemSize.height/2,
                width: itemSize.width,
                height: itemSize.height
            )
            
            if self.isValidPosition(itemRect, existingPositions: positions.map {
                getAbsolutePosition(distance: $0.distance, angle: $0.angle, centerPoint: centerPoint)
            }, itemSize: itemSize) {
                let normalizedDistance = min(distance / maxPossibleDistance, 1.0)
                let scale = self.scaleRange.max - normalizedDistance * (self.scaleRange.max - self.scaleRange.min)
                positions.append(Position(distance: distance, angle: angle, scale: scale))
                
                if absolutePosition.x < centerPoint.x {
                    leftPositions += 1
                } else {
                    rightPositions += 1
                }
            }
        }
        
        return positions
    }
    
    func getAbsolutePosition(distance: CGFloat, angle: CGFloat, centerPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: centerPoint.x + distance * cos(angle),
            y: centerPoint.y + distance * sin(angle)
        )
    }
    
    private func isValidPosition(_ rect: CGRect, existingPositions: [CGPoint], itemSize: CGSize) -> Bool {
        if rect.minX < self.edgePadding || rect.maxX > self.containerSize.width - self.edgePadding ||
            rect.minY < self.edgePadding || rect.maxY > self.containerSize.height - self.edgePadding {
            return false
        }
        
        for zone in self.exclusionZones {
            if rect.intersects(zone) {
                return false
            }
        }
        
        let effectiveMinDistance = existingPositions.count > 5 ? max(self.minimumDistance * 0.7, 10.0) : self.minimumDistance
        
        for existingPosition in existingPositions {
            let distance = hypot(existingPosition.x - rect.midX, existingPosition.y - rect.midY)
            if distance < effectiveMinDistance {
                return false
            }
        }
        
        return true
    }
}

private func getAbsolutePosition(position: PositionGenerator.Position, centerPoint: CGPoint) -> CGPoint {
    return CGPoint(
        x: centerPoint.x + position.distance * cos(position.angle),
        y: centerPoint.y + position.distance * sin(position.angle)
    )
}

private func getAbsolutePosition(distance: CGFloat, angle: CGFloat, centerPoint: CGPoint) -> CGPoint {
    return CGPoint(
        x: centerPoint.x + distance * cos(angle),
        y: centerPoint.y + distance * sin(angle)
    )
}

private func windowFunction(t: CGFloat) -> CGFloat {
    return bezierPoint(0.6, 0.0, 0.4, 1.0, t)
}

private func patternScaleValueAt(fraction: CGFloat, t: CGFloat, reverse: Bool) -> CGFloat {
    let windowSize: CGFloat = 0.8

    let effectiveT: CGFloat
    let windowStartOffset: CGFloat
    let windowEndOffset: CGFloat
    if reverse {
        effectiveT = 1.0 - t
        windowStartOffset = 1.0
        windowEndOffset = -windowSize
    } else {
        effectiveT = t
        windowStartOffset = -windowSize
        windowEndOffset = 1.0
    }

    let windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset
    let windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize
    let localT = 1.0 - windowFunction(t: windowT)

    return localT
}
