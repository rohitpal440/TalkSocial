//
//  FeedViewController.swift
//  TalkSocial
//
//  Created by Rohit Pal on 27/02/24.
//

import UIKit
import ToastViewSwift

class FeedViewController: UIViewController{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    private let maxHeaderHeight: CGFloat = 50
    private let minHeaderHeight: CGFloat = 0
    private var activityIndicator: UIActivityIndicatorView?
    private let refreshControl = UIRefreshControl()

    private var previousScrollOffset: CGFloat = 0
    private var previousScrollViewHeight: CGFloat = 0

    var viewModel: FeedViewModel? = FeedViewModelImpl(service: FeedServiceImpl())
    
    func getActivityIndicator() -> UIActivityIndicatorView {
        guard let activityIndicator else {
            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
            indicator.hidesWhenStopped = true
            indicator.center = self.tableView.center
            self.tableView.addSubview(indicator)
            activityIndicator = indicator
            return indicator
        }
        return activityIndicator
    }
    
    
    func showLoading() {
        getActivityIndicator().startAnimating()
    }
    
    func hideLoading() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        tableView.register(UINib(nibName: "FeedViewCell", bundle: nil), forCellReuseIdentifier: "FeedViewCell")
        tableView.register(UINib(nibName: "LoadingViewCell", bundle: nil), forCellReuseIdentifier: "LoadingViewCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 620
        tableView.rowHeight = UITableView.automaticDimension
        
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
        self.previousScrollViewHeight = self.tableView.contentSize.height
        subscribeObservable()
        viewModel?.viewLoaded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playVideoInMostVisibleCell()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pauseAnyMedia()
    }
    
    @objc private func refreshData(_ sender: Any) {
        viewModel?.didExecutePullToRefresh()
    }
    
    private func subscribeObservable() {
        viewModel?.onLoad =  {[weak self] in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
                self?.tableView.restore()
                self?.tableView.reloadData()
                self?.playVideoInMostVisibleCell()
            }
        }
        
        viewModel?.showNoDataState =  {[weak self] in
            DispatchQueue.main.async {
                self?.tableView.setEmptyMessage("Good things takes time! Waiting to load feed!")
            }
        }
        
        viewModel?.onError = {[weak self] message in
            DispatchQueue.main.async {
                Toast.text(message).show()
            }
        }
        
        viewModel?.updateLoaderVisibility = {[weak self] visible in
            DispatchQueue.main.async {
                visible ? self?.showLoading() : self?.hideLoading()
            }
        }
        
        viewModel?.onReloadRowsUpdate = {[weak self] indexPaths in
            DispatchQueue.main.async {
                self?.tableView.beginUpdates()
                self?.tableView.reloadRows(at: indexPaths, with: .fade)
                self?.tableView.endUpdates()
            }
        }
        
        viewModel?.refreshControlVisibilityUpdate = {[weak self] visible in
            DispatchQueue.main.async {
                visible ? self?.refreshControl.beginRefreshing() : self?.refreshControl.endRefreshing()
            }
        }
        
        viewModel?.navigateToPostDetail = {[weak self] postId in
            DispatchQueue.main.async {
                let vc = ViewControllerFactory.getFeedDetail(postId: postId)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

}

extension FeedViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.getNumberSection() ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (viewModel?.getNumberOfRows(inSection: section) ?? 0) + (viewModel?.canLoadMoreFeed() == true  ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < (viewModel?.getNumberOfRows(inSection: indexPath.section) ?? 0),
                let model = viewModel?.getFeedPostModel(atIndexPath: indexPath) else {
            if indexPath.row == viewModel?.getNumberOfRows(inSection: indexPath.section) {
                viewModel?.didReachAtEnd()
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingViewCell", for: indexPath) as! LoadingViewCell
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedViewCell", for: indexPath) as! FeedViewCell
        cell.setupWith(model: model)
        return cell
    }
    
}

extension FeedViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.didSelectItem(atIndexPath: indexPath)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Always update the previous values
        defer {
            self.previousScrollViewHeight = scrollView.contentSize.height
            self.previousScrollOffset = scrollView.contentOffset.y
            self.playVideoInMostVisibleCell()
        }
        let heightDiff = scrollView.contentSize.height - self.previousScrollViewHeight
        let scrollDiff = (scrollView.contentOffset.y - self.previousScrollOffset)

        // If the scroll was caused by the height of the scroll view changing, we want to do nothing.
        guard heightDiff == 0 else { return }

        let absoluteTop: CGFloat = 0;
        let absoluteBottom: CGFloat = scrollView.contentSize.height - scrollView.frame.size.height;

        let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
        let isScrollingUp = scrollDiff < 0 && scrollView.contentOffset.y < absoluteBottom

        if canAnimateHeader(scrollView) {

            // Calculate new header height
            var newHeight = self.headerHeightConstraint.constant
            if isScrollingDown {
                newHeight = max(self.minHeaderHeight, self.headerHeightConstraint.constant - abs(scrollDiff))
            } else if isScrollingUp {
                newHeight = min(self.maxHeaderHeight, self.headerHeightConstraint.constant + abs(scrollDiff))
            }

            // Header needs to animate
            if newHeight != self.headerHeightConstraint.constant {
                self.headerHeightConstraint.constant = newHeight
                self.updateHeader()
                self.setScrollPosition(self.previousScrollOffset)
            }
        }
    }
    
    func pauseAnyMedia() {
        tableView.visibleCells.forEach { ($0 as? FeedViewCell)?.pauseMedia() }
    }
    
    func playVideoInMostVisibleCell() {
        var visibleCellsInfo: [(cell: FeedViewCell, visiblity: CGFloat)] = []
        for cell in self.tableView.visibleCells {
            if let videoCell = cell as? FeedViewCell {
                let indexPath = tableView.indexPath(for: cell)!
                let cellRect = tableView.rectForRow(at: indexPath)
                let superview = tableView.superview!
                let convertedRect = tableView.convert(cellRect, to: superview)
                let intersectRect = tableView.frame.intersection(convertedRect)
                let visiblePortion = intersectRect.height / cellRect.height
                visibleCellsInfo.append((videoCell, visiblePortion))
            }
        }
        visibleCellsInfo.sort(by: { $0.visiblity > $1.visiblity })
        let mostVisibleCell = visibleCellsInfo.removeFirst()
        visibleCellsInfo.forEach { $0.cell.pauseMedia()}
        mostVisibleCell.cell.playMedia()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollViewDidStopScrolling()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.scrollViewDidStopScrolling()
        }
    }

    func scrollViewDidStopScrolling() {
        let range = self.maxHeaderHeight - self.minHeaderHeight
        let midPoint = self.minHeaderHeight + (range / 2)

        if self.headerHeightConstraint.constant > midPoint {
            self.expandHeader()
        } else {
            self.collapseHeader()
        }
    }

    func canAnimateHeader(_ scrollView: UIScrollView) -> Bool {
        // Calculate the size of the scrollView when header is collapsed
        let scrollViewMaxHeight = scrollView.frame.height + self.headerHeightConstraint.constant - minHeaderHeight

        // Make sure that when header is collapsed, there is still room to scroll
        return scrollView.contentSize.height > scrollViewMaxHeight
    }

    func collapseHeader() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2, animations: {
            self.headerHeightConstraint.constant = self.minHeaderHeight
            self.updateHeader()
            self.view.layoutIfNeeded()
        })
    }

    func expandHeader() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2, animations: {
            self.headerHeightConstraint.constant = self.maxHeaderHeight
            self.updateHeader()
            self.view.layoutIfNeeded()
        })
    }

    func setScrollPosition(_ position: CGFloat) {
        self.tableView.contentOffset = CGPoint(x: self.tableView.contentOffset.x, y: position)
    }

    func updateHeader() {
        let range = self.maxHeaderHeight - self.minHeaderHeight
        let openAmount = self.headerHeightConstraint.constant - self.minHeaderHeight
        let percentage = openAmount / range
        // Do more based on percentage
    }
}
