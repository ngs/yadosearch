//
//  SearchRootViewController.swift
//  YadoSearch
//
//  Created by Atsushi Nagase on 9/21/14.
//  Copyright (c) 2014 LittleApps Inc. All rights reserved.
//

import UIKit

class SearchRootViewController: UIViewController {
  var searchFormNavigationController: UINavigationController!
  @IBOutlet var containerView: UIView!
  @IBOutlet var searchTypeSegment: UISegmentedControl!
  @IBOutlet var siteSegment: UISegmentedControl!
  @IBAction func searchTypeSegmentChanged(sender: AnyObject?) {
    var id: String =
    [
      "keyword",
      "currentLocation",
      "area",
      "railway"
      ][searchTypeSegment.selectedSegmentIndex] + "Search"
    let vcs: [SearchFormViewController] = searchFormNavigationController.viewControllers as [SearchFormViewController]
    for var i = 0; i < vcs.count; i++ {
      var vc: SearchFormViewController = vcs[i]
      vc.rootViewController = self
      if(vc.restorationIdentifier == id + "ViewController") {
        searchFormNavigationController.popToViewController(vc, animated: true)
        return
      }
    }
    searchFormNavigationController.topViewController.performSegueWithIdentifier("show_" + id, sender: sender)
  }
  @IBAction func siteSegmentChanged(sender: AnyObject?) {
  }
  override func viewDidLoad() {
    siteSegmentChanged(nil)
    searchTypeSegmentChanged(nil)
  }
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "searchFormNavigationSegue" {
      searchFormNavigationController = segue.destinationViewController as UINavigationController
    }
  }
}
