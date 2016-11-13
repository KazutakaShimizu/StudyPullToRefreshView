//
//  PullToRefreshConst.swift
//  PullToRefreshSwift
//
//  Created by Yuji Hato on 12/11/14.
//  Qiulang rewrites it to support pull down & push up
//
import UIKit

open class PullToRefreshView: UIView {
    enum PullToRefreshState {
        case pulling
        case triggered
        case refreshing
        case stop
        case finish
    }
    
    // MARK: Variables
    let contentOffsetKeyPath = "contentOffset"
    let contentSizeKeyPath = "contentSize"
    var kvoContext = "PullToRefreshKVOContext"
    
    fileprivate var options: PullToRefreshOption
    fileprivate var backgroundView: UIView
    fileprivate var arrow: UIImageView
    fileprivate var indicator: UIActivityIndicatorView
    fileprivate var scrollViewInsets: UIEdgeInsets = UIEdgeInsets.zero
    fileprivate var refreshCompletion: ((Void) -> Void)?
//    イニシャライズの引数downが入ってくる
    fileprivate var pull: Bool = true
    
    fileprivate var positionY:CGFloat = 0 {
        didSet {
            if self.positionY == oldValue {
                return
            }
            var frame = self.frame
            frame.origin.y = positionY
            self.frame = frame
        }
    }
    
    var state: PullToRefreshState = PullToRefreshState.pulling {
        didSet {
//            stateに入ってきた値が前のものと変わらない場合
            if self.state == oldValue {
                return
            }
            switch self.state {
//            インジケーターのアニメーションをストップ
            case .stop:
                stopAnimating()
//                アニメーションをストップして、それ以上引っ張って更新をできないようにする
//            PullToRefreshView自体を呼び出し元のビューから削除
            case .finish:
                var duration = PullToRefreshConst.animationDuration
                var time = DispatchTime.now() + Double(Int64(duration * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: time) {
                    self.stopAnimating()
                }
                duration = duration * 2
                time = DispatchTime.now() + Double(Int64(duration * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: time) {
                    self.removeFromSuperview()
                }
            case .refreshing:
//            アニメーションをスタート
                startAnimating()
            case .pulling: //starting point
//            →の向きをもとに戻している
                arrowRotationBack()
            case .triggered:
//                リロードできる高さまで引っ張ってきたら、statusがpullingになる
//            →の向きを変えている
                arrowRotation()
            }
        }
    }
    
    // MARK: UIView
    public override convenience init(frame: CGRect) {
        self.init(options: PullToRefreshOption(),frame:frame, refreshCompletion:nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    引っ張った時に伸びる部分、ひっぱた時に表示される画像、インジケーターを設定し、addsubViewしている
//    downの部分の真偽値がプロパティのpullに入ってくる
    public init(options: PullToRefreshOption, frame: CGRect, refreshCompletion :((Void) -> Void)?, down:Bool=true) {
        self.options = options
        self.refreshCompletion = refreshCompletion
        
//        引っ張った時に伸びる部分がbackgroundView。サイズと色をセット
        self.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        self.backgroundView.backgroundColor = self.options.backgroundColor
        
//        AutoresizingMaskとは、親ビューのboundsが変更された時に自動で上下左右のマージンや幅・高さを変更する
//        backgroundViewのwidthを、親ビューのサイズに合わせて可変にする
        self.backgroundView.autoresizingMask = UIViewAutoresizing.flexibleWidth
        
        self.arrow = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        self.arrow.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        
//        引っ張った時に出てくる画像を作っている。PullToRefreshConst.imageNameを変更すれば、自分で画像を登録できそう
        self.arrow.image = UIImage(named: PullToRefreshConst.imageName, in: Bundle(for: type(of: self)), compatibleWith: nil)
        
//        インジゲーターを設定
        self.indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        self.indicator.bounds = self.arrow.bounds
        self.indicator.autoresizingMask = self.arrow.autoresizingMask
        self.indicator.hidesWhenStopped = true
        self.indicator.color = options.indicatorColor
        self.pull = down
        
        super.init(frame: frame)
        self.addSubview(indicator)
        self.addSubview(backgroundView)
        self.addSubview(arrow)
        self.autoresizingMask = .flexibleWidth
    }
   
    
//    layoutsubViewsは、テーブルビューを引っ張る度に呼ばれる
    open override func layoutSubviews() {
        super.layoutSubviews()
//        引っ張った時に出てくるアイコンの位置を真ん中らになるように設定
        self.arrow.center = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        self.arrow.frame = arrow.frame.offsetBy(dx: 0, dy: 0)
//        インジゲーターの位置も同様に真ん中にする
        self.indicator.center = self.arrow.center
    }
    
//    superViewが変化した時に呼び出されるメソッド
    open override func willMove(toSuperview superView: UIView!) {
        //superview NOT superView, DO NEED to call the following method
        //superview dealloc will call into this when my own dealloc run later!!
//        PullToRefreshViewの親ビューが存在すれば、そのobserverを解除する
        self.removeRegister()
        guard let scrollView = superView as? UIScrollView else {
            return
        }
        
//        addObserverを使って、contentOffsetの値を監視している
//        contentoffsetの数値はスクロールするたびに変わる
        scrollView.addObserver(self, forKeyPath: contentOffsetKeyPath, options: .initial, context: &kvoContext)
//        pullがfalseだったら
        if !pull {
//            contentSizeの値を監視
            scrollView.addObserver(self, forKeyPath: contentSizeKeyPath, options: .initial, context: &kvoContext)
        }
    }
//    observerを解除している
    fileprivate func removeRegister() {
//        自分の親のuiVIewクラスが存在すれば
//        通常は、PullToRefreshViewはtableViewなどの子クラスとなっている
        if let scrollView = superview as? UIScrollView {
//            ここの処理が走るのは、引っ張り上げてリロードした際。引き下げる場合とは何か違う形でviewをリロードしている？
//            引っ張り上げる場合は、リロードの際に一度このクラスを親ビューからremoveしてるっぽい
            scrollView.removeObserver(self, forKeyPath: contentOffsetKeyPath, context: &kvoContext)
            if !pull {
                scrollView.removeObserver(self, forKeyPath: contentSizeKeyPath, context: &kvoContext)
            }
        }
    }
    
    deinit {
        self.removeRegister()
    }
    
    // MARK: KVO
//    observerで監視してる値が変化した際に呼ばれるメソッド
//    スクロールするたびに呼ばれており、ある一定値までスクロールした際にstateを変更することで、→の動きなどを実装している
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let scrollView = object as? UIScrollView else {
            return
        }
//        contentSizeが変わったら
        if keyPath == contentSizeKeyPath {
//            PullToRefreshViewのyをscrollViewのcontentSizeの下端の部分に合わせる
            self.positionY = scrollView.contentSize.height
            return
        }
        
//        context == &kvoContextでなく、かつkeyPath == contentOffsetKeyPathでない場合
        if !(context == &kvoContext && keyPath == contentOffsetKeyPath) {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        // Pulling State Check
//        現在どの位置までスクロールされているのか
        let offsetY = scrollView.contentOffset.y
        
        // Alpha set
        if PullToRefreshConst.alpha {
//            offsetYの絶対値/PullToRefreshViewの高さ+40
//            下にスクロールしていくと、alphaも0.8を超える
            var alpha = fabs(offsetY) / (self.frame.size.height + 40)
            if alpha > 0.8 {
                alpha = 0.8
            }
//            引っ張ると表示される→部分の透明度を設定
//            引っ張ると徐々に→の色が濃くなってくる
            self.arrow.alpha = alpha
        }
        
//        pullでのリフレッシュの処理
//        引っ張っると、offsetYの値はマイナスになる
        if offsetY <= 0 {
//            pullではなくpushでリロードの場合はここでリターンになる
            if !self.pull {
                return
            }
//            offsetYはどれだけscrollViewの余剰分を引っ張っているか
//            frameのheightはoptionで設定したrefreshViewの高さ（＝どこまで引っ張ったらリフレッシュの処理が走るか）
            print(self.frame.size.height)
            print(offsetY)
            if offsetY < -self.frame.size.height {
                // pulling or refreshing
//                isDraggingが謎
                if scrollView.isDragging == false && self.state != .refreshing { //release the finger
                    self.state = .refreshing //startAnimating
                } else if self.state != .refreshing { //reach the threshold
//                    stateがregreshingの時は、didSetの中でアニメーションがスタートしている
//                    ここではstateを切り替えるだけ
//                    stateがtriggeredの時は→の向きを逆に変えている
                    self.state = .triggered
                }
            } else if self.state == .triggered {
                //starting point, start from pulling
//                引っ張りの大きさがリフレッシュの基準値より小さくなれば
//                ステータスをpullingにして、→の向きを戻している
                self.state = .pulling
            }
            return //return for pull down
        }
        
        //push up
//        pushでのローディングの実装はここ
//        self.pullの値を見てる
        let upHeight = offsetY + scrollView.frame.size.height - scrollView.contentSize.height
        if upHeight > 0 {
            // pulling or refreshing
            if self.pull {
                return
            }
            if upHeight > self.frame.size.height {
                // pulling or refreshing
                if scrollView.isDragging == false && self.state != .refreshing { //release the finger
                    self.state = .refreshing //startAnimating
                } else if self.state != .refreshing { //reach the threshold
                    self.state = .triggered
                }
            } else if self.state == .triggered  {
                //starting point, start from pulling
                self.state = .pulling
            }
        }
    }
    
    // MARK: private
    
//    インジケーターのアニメーションをスタート
    fileprivate func startAnimating() {
        self.indicator.startAnimating()
//        →の画像を消す
        self.arrow.isHidden = true
        guard let scrollView = superview as? UIScrollView else {
            return
        }
//        スクロールビューの余白部分をプロパティに保存
        scrollViewInsets = scrollView.contentInset
        
        var insets = scrollView.contentInset
        
//        pullでリロードか、pushでリロードかでinsetの位置を変更している
//        インジケーターが回ってる間、contentInsetを設定しscrollVIewの余白をとらなければ、インジケーターが回転するスペースがなくなってしまう
        if pull {
//            上側の余白をとる
            insets.top += self.frame.size.height
        } else {
//            scrollViewの下側の余白をとる
            insets.bottom += self.frame.size.height
        }
//        スクロールのバウンドをなしにする
        scrollView.bounces = false
        
//        アニメーションスタート
//        refreshViewを引っ張りすぎた時に、リロードしながら設定した高さまで戻ってくるアニメーションを設定している
        UIView.animate(withDuration: PullToRefreshConst.animationDuration,
                                   delay: 0,
                                   options:[],
                                   animations: {
            scrollView.contentInset = insets
            },
                                   completion: { _ in
                
                if self.options.autoStopTime != 0 {
//                    現在の時間にautostoptimeを足す
                    let time = DispatchTime.now() + Double(Int64(self.options.autoStopTime * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                    
                    DispatchQueue.main.asyncAfter(deadline: time) {
                    
//                        stateをstopに変更（stopanimatingを呼び出す）
                        self.state = .stop
                    }
                }
                                    
//                イニシャライザの引数にとったcompletionメソッドがここで呼ばれる
                self.refreshCompletion?()
        })
    }
    
//    インジケーターのアニメーションをストップする
    fileprivate func stopAnimating() {
//        インジケーターのアニメーションをストップ
        self.indicator.stopAnimating()
//        →を表示
        self.arrow.isHidden = false
        guard let scrollView = superview as? UIScrollView else {
            return
        }
//        バウンドを元に戻す
        scrollView.bounces = true
        
        let duration = PullToRefreshConst.animationDuration
        UIView.animate(withDuration: duration,
                                   animations: {
//                                    ここがアニメーション後の状態
                                    scrollView.contentInset = self.scrollViewInsets
                                    self.arrow.transform = CGAffineTransform.identity
                                    }, completion: { _ in
            self.state = .pulling
        }
        ) 
    }
    
//    最初は下向きの→を、上むきに変えている
    fileprivate func arrowRotation() {
        UIView.animate(withDuration: 0.2, delay: 0, options:[], animations: {
            // -0.0000001 for the rotation direction control
            self.arrow.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI-0.0000001))
        }, completion:nil)
    }
//    →の向きを最初に戻す
    fileprivate func arrowRotationBack() {
        UIView.animate(withDuration: 0.2, animations: {
            self.arrow.transform = CGAffineTransform.identity
        }) 
    }
}
