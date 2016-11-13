//
//  PullToRefreshConst.swift
//  PullToRefreshSwift
//
//  Created by Yuji Hato on 12/11/14.
//
import Foundation
import UIKit

public extension UIScrollView {
    
//    tagはとってきたいrefreshViewのタグ
//    tagにマッチするrefreshViewをとってくる
    fileprivate func refreshViewWithTag(_ tag:Int) -> PullToRefreshView? {
        let pullToRefreshView = viewWithTag(tag)
        return pullToRefreshView as? PullToRefreshView
    }
    
//    refreshViewの設定をライブラリを使っているviewからもらい、refreshViewを生成し、追加する
//    optionsはrefreshViewの設定、completionはリフレッシュ後に走る処理
    public func addPullRefresh(options: PullToRefreshOption = PullToRefreshOption(), refreshCompletion :((Void) -> Void)?) {
//        引っ張ってきて、リフレッシュした際、インジゲーターが表示されている部分の設定
//        高さ分y軸をずらさないと、引っ張る前からrefreshViewFrameが見えてしまう
        let refreshViewFrame = CGRect(x: 0, y: -PullToRefreshConst.height, width: self.frame.size.width, height: PullToRefreshConst.height)
//        設定とviewのサイズ、completionを渡しつつrefreshViewを生成
        let refreshView = PullToRefreshView(options: options, frame: refreshViewFrame, refreshCompletion: refreshCompletion)
//        タグはpullの場合とpushの場合で違うものが入ってくる
        refreshView.tag = PullToRefreshConst.pullTag
        addSubview(refreshView)
    }
    
    public func addPushRefresh(options: PullToRefreshOption = PullToRefreshOption(), refreshCompletion :((Void) -> Void)?) {
        let refreshViewFrame = CGRect(x: 0, y: contentSize.height, width: self.frame.size.width, height: PullToRefreshConst.height)
        let refreshView = PullToRefreshView(options: options, frame: refreshViewFrame, refreshCompletion: refreshCompletion,down: false)
        refreshView.tag = PullToRefreshConst.pushTag
        addSubview(refreshView)
    }
    
    public func startPullRefresh() {
//        pull方のrefreshViewをとってくる
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pullTag)
//        stateをrefreshingに変えて、インジケーターのアニメーションをスタート
        refreshView?.state = .refreshing
    }
    
//    everは二回目以降のrefreshを受け付けるか
//    trueになっていると二回目以降のリフレッシュを受け付けない
//    下向きに引っ張ってリロードの際は、false、上向きはtrueになっている
    public func stopPullRefreshEver(_ ever:Bool = false) {
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pullTag)
//        stateをfinishにすると二回目以降のリフレッシュができない
        if ever {
            refreshView?.state = .finish
        } else {
//            stopは二回目以降もできる
            refreshView?.state = .stop
        }
    }
    
    
    public func removePullRefresh() {
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pullTag)
        refreshView?.removeFromSuperview()
    }
    
    public func startPushRefresh() {
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pushTag)
        refreshView?.state = .refreshing
    }
    
    public func stopPushRefreshEver(_ ever:Bool = false) {
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pushTag)
        if ever {
            refreshView?.state = .finish
        } else {
            refreshView?.state = .stop
        }
    }
    
    public func removePushRefresh() {
        let refreshView = self.refreshViewWithTag(PullToRefreshConst.pushTag)
        refreshView?.removeFromSuperview()
    }
    
    // If you want to PullToRefreshView fixed top potision, Please call this function in scrollViewDidScroll
    public func fixedPullToRefreshViewForDidScroll() {
        let pullToRefreshView = self.refreshViewWithTag(PullToRefreshConst.pullTag)
        if !PullToRefreshConst.fixedTop || pullToRefreshView == nil {
            return
        }
        var frame = pullToRefreshView!.frame
        if self.contentOffset.y < -PullToRefreshConst.height {
            frame.origin.y = self.contentOffset.y
            pullToRefreshView!.frame = frame
        }
        else {
            frame.origin.y = -PullToRefreshConst.height
            pullToRefreshView!.frame = frame
        }
    }
}
