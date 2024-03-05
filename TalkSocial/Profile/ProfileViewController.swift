//
//  ProfileViewController.swift
//  TalkSocial
//
//  Created by Rohit Pal on 02/03/24.
//

import UIKit
import ToastViewSwift

class ProfileViewController: UIViewController {

    @IBOutlet private  weak var collectionView: UICollectionView!
    private var activityIndicator: UIActivityIndicatorView?
    private let refreshControl = UIRefreshControl()
    private let headerViewHeight: CGFloat = 270
    
    private let numberOfColumns: CGFloat = 3
    private let spacing: CGFloat = 2
    var viewModel: UserProfileViewModel?
    
    func getActivityIndicator() -> UIActivityIndicatorView {
        guard let activityIndicator else {
            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
            indicator.hidesWhenStopped = true
            indicator.center = self.collectionView.center
            self.collectionView.addSubview(indicator)
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
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .white
        collectionView.register(UINib(nibName: "UserPostsCell", bundle: nil), forCellWithReuseIdentifier: "UserPostsCell")
        collectionView.register(UINib(nibName: "NoPostCell", bundle: nil), forCellWithReuseIdentifier: "NoPostCell")
        collectionView.register(UINib(nibName: "ProfileHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ProfileHeaderView")
        collectionView.reloadData()
        // Do any additional setup after loading the view.
        collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
        subscribeObservable()
        viewModel?.viewLoaded()
    }

    
    @objc private func refreshData(_ sender: Any) {
        viewModel?.didExecutePullToRefresh()
    }
    
    private func subscribeObservable() {
        viewModel?.onLoad =  {[weak self] in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
                self?.collectionView.reloadData()
                self?.collectionView.restore()
            }
        }
        
        viewModel?.showNoDataState =  {[weak self] in
            DispatchQueue.main.async {
                self?.collectionView.setEmptyMessage("Failed to load your profile")
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ProfileViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel?.getNumberSection() ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var extraCells = viewModel?.hasNotPostedAnything() == true ? 1 : 0
        return extraCells + (viewModel?.getNumberOfRows(inSection: section) ?? 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let model = viewModel?.getFeedPostModel(atIndexPath: indexPath) else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoPostCell", for: indexPath) as! NoPostCell
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UserPostsCell", for: indexPath) as! UserPostsCell
        // Configure the cell with your photo data
        // cell.photoImageView.image = ...
        cell.backgroundColor = .gray
        cell.setup(viewModel: model)
        return cell
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let model = viewModel?.getFeedPostModel(atIndexPath: indexPath) else {
            return .init(width: collectionView.bounds.width, height: headerViewHeight)
        }
        let width = (collectionView.bounds.width - (numberOfColumns + 1) * spacing) / numberOfColumns
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: headerViewHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ProfileHeaderView", for: indexPath) as! ProfileHeaderView
        // Configure the header view
        // headerView.titleLabel.text = ...
        let model = viewModel?.getHeaderModel(atSection: indexPath.section)
        headerView.setup(userName: model?.userName ?? "", about: model?.about, profiePicUrl: model?.profilePicUrl)
        headerView.backgroundColor = .brown
        return headerView
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel?.didSelectItem(atIndexPath: indexPath)
    }
}
