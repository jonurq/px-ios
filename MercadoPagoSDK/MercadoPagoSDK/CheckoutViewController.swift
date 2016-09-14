//
//  CheckoutViewController.swift
//  MercadoPagoSDK
//
//  Created by Maria cristina rodriguez on 13/1/16.
//  Copyright © 2016 MercadoPago. All rights reserved.
//

import UIKit
import MercadoPagoTracker

public class CheckoutViewController: MercadoPagoUIViewController, UITableViewDataSource, UITableViewDelegate, TermsAndConditionsDelegate {

    var preferenceId : String!
    var preference : CheckoutPreference?
    var publicKey : String!
    var accessToken : String!
    var bundle : NSBundle? = MercadoPago.getBundle()
    var callback : (Payment -> Void)!
   
    var viewModel : CheckoutViewModel?
    
    var issuer : Issuer?
    var token : Token?
    
    var payerCost : PayerCost?
    override public var screenName : String { get{ return "REVIEW_AND_CONFIRM" } }
    private var reviewAndConfirmContent = Set<String>()
    
    private var recover = false
    private var auth = false
    
    @IBOutlet weak var checkoutTable: UITableView!
    
    init(preferenceId : String, callback : (Payment -> Void),  callbackCancel : (Void -> Void)? = nil){
        super.init(nibName: "CheckoutViewController", bundle: MercadoPago.getBundle())
        self.publicKey = MercadoPagoContext.publicKey()
        self.accessToken = MercadoPagoContext.merchantAccessToken()
        self.preferenceId = preferenceId
        self.viewModel = CheckoutViewModel()
        self.callback = callback
        self.callbackCancel = {
                self.dismissViewControllerAnimated(true, completion: {
                    if(callbackCancel != nil){
                            callbackCancel!()
                  }
                })
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {

        super.viewDidLoad()
        
        self.checkoutTable.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0.01))
        
        //Display preference description by default
        self.displayPreferenceDescription = true
        
        self.title = "¿Cómo quieres pagar?".localized

    }
    

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
    }

    
    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.showLoading()
        if preference == nil {
            self.displayBackButton()
            self.navigationItem.leftBarButtonItem?.action = Selector("invokeCallbackCancel")
            self.loadPreference()
        } else {
            if self.viewModel!.paymentMethod != nil {
                self.title = "Revisa si está todo bien...".localized
                self.checkoutTable.reloadData()
                self.hideLoading()
                if (recover){
                    recover = false
                    self.startRecoverCard()
                }
                if (auth){
                    auth = false
                    self.startAuthCard()
                }
                
            } else {
                self.displayBackButton()
                self.navigationItem.leftBarButtonItem?.action = Selector("invokeCallbackCancel")
                self.loadGroupsAndStartPaymentVault(true)
            }
        }

    }
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 && displayPreferenceDescription {
            return 0.1
        }
        return 13
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if self.displayPreferenceDescription {
                return 120
            }
            return 0
        }
        
        switch indexPath.row {
        case 0:
            if self.viewModel!.isPaymentMethodSelectedCard() {
                return 48
            }
            return 80
        case 1:
            if self.viewModel!.isPaymentMethodSelectedCard() {
                return 48
            }
            return 60
        case 2:
            if self.viewModel!.isPaymentMethodSelectedCard() {
                return 50
            }
            return 160
        default:
            return 160
        }
    }
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.viewModel!.numberOfSections()
    }
    

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // Purchase description
            return 1
        }
       return self.viewModel!.numberOfRowsInMainSection()
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    
        if indexPath.section == 0 {
            let preferenceDescriptionCell = tableView.dequeueReusableCellWithIdentifier("preferenceDescriptionCell", forIndexPath: indexPath) as! PreferenceDescriptionTableViewCell
            preferenceDescriptionCell.fillRowWithPreference(self.preference!)
            return preferenceDescriptionCell
        }
        
        if self.viewModel!.isPaymentMethodSelectedCard() {
            return self.drawCreditCardTable(indexPath)
        } else {
            return self.drawOfflinePaymentMethodTable(indexPath)
        }
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            self.checkoutTable.deselectRowAtIndexPath(indexPath, animated: true)
        } else if indexPath.section == 1 && indexPath.row == 0 && !self.viewModel!.isUniquePaymentMethodAvailable() {
            self.checkoutTable.deselectRowAtIndexPath(indexPath, animated: true)
            self.showLoading()
            self.loadGroupsAndStartPaymentVault()
        } else if indexPath.section == 1 && indexPath.row == 1 && self.viewModel!.isPaymentMethodSelectedCard() {
            startPayerCostStep()
        }
    }
    
    
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return (section == 1) ? 44 : 0.1
    }

    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 1 {
            let exitButtonCell =  self.checkoutTable.dequeueReusableCellWithIdentifier("exitButtonCell") as! ExitButtonTableViewCell
            exitButtonCell.callbackCancel = {
                self.dismissViewControllerAnimated(true, completion: {})
            }
            exitButtonCell.exitButton.addTarget(self, action: "exitCheckoutFlow", forControlEvents: .TouchUpInside)
            return exitButtonCell
        }
        return nil
    }
    
    internal func loadGroupsAndStartPaymentVault(animated : Bool = true){
        
        if self.viewModel!.paymentMethodSearch == nil {
            MPServicesBuilder.searchPaymentMethods(self.preference!.getAmount(), excludedPaymentTypeIds: self.preference?.getExcludedPaymentTypesIds(), excludedPaymentMethodIds: self.preference?.getExcludedPaymentMethodsIds(), success: { (paymentMethodSearch) in
                self.viewModel!.paymentMethodSearch = paymentMethodSearch
                
                self.startPaymentVault()
                }, failure: { (error) in
                    self.requestFailure(error, callback: {}, callbackCancel:
                        {
                            self.navigationController!.dismissViewControllerAnimated(true, completion: {
                            })})
            })
        } else {
            self.startPaymentVault(animated)
        }
        
    }
    
    internal func startPaymentVault(animated : Bool = false){
        self.registerAllCells()
        
        let paymentVaultVC = MPFlowBuilder.startPaymentVaultInCheckout(self.preference!.getAmount(), paymentPreference: self.preference!.getPaymentPreference(), paymentMethodSearch: self.viewModel!.paymentMethodSearch!, callback: { (paymentMethod, token, issuer, payerCost) in
            self.paymentVaultCallback(paymentMethod, token : token, issuer : issuer, payerCost : payerCost, animated : animated)
        })
        
        var callbackCancel : (Void -> Void)
        
        // Set action for cancel callback
        if self.viewModel!.paymentMethod == nil {
            callbackCancel = { Void -> Void in
                self.callbackCancel!()
            }
        } else {
            callbackCancel = { Void -> Void in
               self.navigationController!.popViewControllerAnimated(true)
            }
        }
        self.hideLoading()
        self.navigationItem.leftBarButtonItem = nil
        (paymentVaultVC.viewControllers[0] as! PaymentVaultViewController).callbackCancel = callbackCancel
        self.navigationController?.pushViewController(paymentVaultVC.viewControllers[0], animated: animated)
        
    }
    
    internal func startRecoverCard(){
        let cardFlow = MPFlowBuilder.startCardFlow(amount: (self.preference?.getAmount())!, cardInformation : nil, callback: { (paymentMethod, token, issuer, payerCost) in
             self.paymentVaultCallback(paymentMethod, token : token, issuer : issuer, payerCost : payerCost, animated : true)
            }, callbackCancel: {
                self.navigationController!.popToViewController(self, animated: true)
        })
        self.navigationController?.pushViewController(cardFlow.viewControllers[0], animated: true)
        
    }
    internal func startAuthCard(){
        let cardFlow = MPFlowBuilder.startCardFlow(amount: (self.preference?.getAmount())!, cardInformation : nil, callback: { (paymentMethod, token, issuer, payerCost) in
            self.paymentVaultCallback(paymentMethod, token : token, issuer : issuer, payerCost : payerCost, animated : true)
            }, callbackCancel: {
                self.navigationController!.popToViewController(self, animated: true)
        })
        self.navigationController?.pushViewController(cardFlow.viewControllers[0], animated: true)
        
    }
    
    
    internal func confirmPayment(){
        
        self.showLoading()
        if self.viewModel!.isPaymentMethodSelectedCard(){
            self.confirmPaymentOn()
        } else {
            self.confirmPaymentOff()
        }
    }
    
    internal func paymentVaultCallback(paymentMethod : PaymentMethod, token : Token?, issuer : Issuer?, payerCost : PayerCost?, animated : Bool = true){

        let transition = CATransition()
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.navigationController!.view.layer.addAnimation(transition, forKey: nil)
        self.navigationController!.popToRootViewControllerAnimated(animated)
        self.showLoading()
        
        self.viewModel!.paymentMethod = paymentMethod
        self.token = token
        self.issuer = issuer
        self.payerCost = payerCost
    }
    
    
    internal func confirmPaymentOff(){
        MercadoPago.createMPPayment(self.preference!.payer.email, preferenceId: self.preference!._id, paymentMethod: self.viewModel!.paymentMethod!, token : self.token, success: { (payment) -> Void in

            MPTracker.trackPaymentOffEvent(String(payment._id), mpDelegate: MercadoPagoContext.sharedInstance)
            
           self.displayPaymentResult(payment)
           }, failure : { (error) -> Void in
                self.requestFailure(error, callback: {
                    self.navigationController?.dismissViewControllerAnimated(true, completion: {})
                    self.confirmPayment()
                })
        })
        
    }

    internal func confirmPaymentOn(){
        MercadoPago.createMPPayment(self.preference!.payer.email, preferenceId: self.preference!._id, paymentMethod: self.viewModel!.paymentMethod!,token : self.token, installments: self.payerCost!.installments , issuer: self.issuer,success: { (payment) -> Void in
            
            
                self.clearMercadoPagoStyle()
                self.navigationController!.popViewControllerAnimated(true)

                self.displayPaymentResult(payment)
          
            }, failure : { (error) -> Void in
                self.requestFailure(error, callback: {
                    self.navigationController?.dismissViewControllerAnimated(true, completion: {})
                    self.confirmPayment()
                })
        })
    }
    
    internal func displayPaymentResult(payment: Payment){
        
        let congrats = MPStepBuilder.startPaymentResultStep(payment, paymentMethod: self.viewModel!.paymentMethod!, callback: { (payment, status) in
            if status == MPStepBuilder.CongratsState.CANCEL_SELECT_OTHER || status == MPStepBuilder.CongratsState.CANCEL_RETRY {
                self.navigationController!.setNavigationBarHidden(false, animated: false)
                self.viewModel!.paymentMethod = nil
                self.navigationController!.viewControllers[0].title = ""
                self.navigationController!.popToRootViewControllerAnimated(false)
            } else  if status == MPStepBuilder.CongratsState.CANCEL_RECOVER {
                self.navigationController!.setNavigationBarHidden(false, animated: false) 
                self.navigationController!.viewControllers[0].title = ""
                self.navigationController!.popToRootViewControllerAnimated(false)
                self.recover = true
            }else  if status == MPStepBuilder.CongratsState.CALL_FOR_AUTH {
                self.navigationController!.setNavigationBarHidden(false, animated: false)
                self.navigationController!.viewControllers[0].title = ""
                self.navigationController!.popToRootViewControllerAnimated(false)
                self.auth = true
            }else {
                self.dismissViewControllerAnimated(true, completion: {})
                self.callback(payment)
            }
        })
        self.navigationController!.pushViewController(congrats, animated: true)
    }
 
    private func loadPreference(){
        MPServicesBuilder.getPreference(self.preferenceId, success: { (preference) in
                if let error = preference.validate() {
                    // Invalid preference - cannot continue
                    let mpError =  MPError(message: "Hubo un error".localized, messageDetail: error, retry: false)
                    self.displayFailure(mpError)
                } else {
                    self.preference = preference
                    self.preference?.loadingImageWithCallback({ (void) in
                        self.checkoutTable.reloadData()
                    })
                    self.loadGroupsAndStartPaymentVault(false)
                }
            }, failure: { (error) in
                // Error in service - retry
                self.requestFailure(error, callback: {
                    self.loadPreference()
                    }, callbackCancel: {
                    self.navigationController!.dismissViewControllerAnimated(true, completion: {})
                })
        })
    }
    
    internal func startPayerCostStep(){
        let pcf = MPStepBuilder.startPayerCostForm(self.viewModel!.paymentMethod, issuer: self.issuer, token: self.token!, amount: self.preference!.getAmount(), paymentPreference: self.preference!.paymentPreference, callback: { (payerCost) -> Void in
            self.payerCost = payerCost
            self.navigationController?.popViewControllerAnimated(true)
            self.checkoutTable.reloadData()
        })
        pcf.callbackCancel = { self.navigationController?.popViewControllerAnimated(true)}
        self.navigationController?.pushViewController(pcf, animated: true)
    }
    
    internal func registerAllCells(){
        
        //Register rows
        let offlinePaymentMethodNib = UINib(nibName: "OfflinePaymentMethodCell", bundle: self.bundle)
        self.checkoutTable.registerNib(offlinePaymentMethodNib, forCellReuseIdentifier: "offlinePaymentCell")
        let preferenceDescriptionCell = UINib(nibName: "PreferenceDescriptionTableViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(preferenceDescriptionCell, forCellReuseIdentifier: "preferenceDescriptionCell")
        let selectPaymentMethodCell = UINib(nibName: "SelectPaymentMethodCell", bundle: self.bundle)
        self.checkoutTable.registerNib(selectPaymentMethodCell, forCellReuseIdentifier: "selectPaymentMethodCell")
        let paymentDescriptionFooter = UINib(nibName: "PaymentDescriptionFooterTableViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(paymentDescriptionFooter, forCellReuseIdentifier: "paymentDescriptionFooter")
        let purchaseTermsAndConditions = UINib(nibName: "TermsAndConditionsViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(purchaseTermsAndConditions, forCellReuseIdentifier: "purchaseTermsAndConditions")
        let exitButtonCell = UINib(nibName: "ExitButtonTableViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(exitButtonCell, forCellReuseIdentifier: "exitButtonCell")
        
        // Payment ON rows
        let paymentSelectedCell = UINib(nibName: "PaymentMethodSelectedTableViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(paymentSelectedCell, forCellReuseIdentifier: "paymentSelectedCell")
        let installmentSelectionCell = UINib(nibName: "InstallmentSelectionTableViewCell", bundle: self.bundle)
        self.checkoutTable.registerNib(installmentSelectionCell, forCellReuseIdentifier: "installmentSelectionCell")
        
        self.checkoutTable.delegate = self
        self.checkoutTable.dataSource = self
        self.checkoutTable.separatorStyle = .None
    }
    
    internal func drawOfflinePaymentMethodTable(indexPath : NSIndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = self.checkoutTable.dequeueReusableCellWithIdentifier("offlinePaymentCell") as! OfflinePaymentMethodCell
            cell.fillRowWithPaymentMethod(self.viewModel!.paymentMethod!, paymentMethodSearchItemSelected: self.viewModel!.paymentMethodSearchItemSelected())
            if self.viewModel!.isUniquePaymentMethodAvailable() {
                cell.selectionStyle = .None
                cell.accessoryType = .None
            }
            return cell
        case 1 :
            let footer = self.checkoutTable.dequeueReusableCellWithIdentifier("paymentDescriptionFooter") as! PaymentDescriptionFooterTableViewCell
            
            footer.layer.shadowOffset = CGSizeMake(0, 1)
            footer.layer.shadowColor = UIColor(red: 153, green: 153, blue: 153).CGColor
            footer.layer.shadowRadius = 1
            footer.layer.shadowOpacity = 0.6
            footer.setAmount(self.preference!.getAmount(), currency: CurrenciesUtil.getCurrencyFor(self.preference!.getCurrencyId()))
            return footer
        case 2 :
            let termsAndConditionsButton = self.checkoutTable.dequeueReusableCellWithIdentifier("purchaseTermsAndConditions") as! TermsAndConditionsViewCell
            termsAndConditionsButton.paymentButton.addTarget(self, action: "confirmPayment", forControlEvents: .TouchUpInside)
            termsAndConditionsButton.delegate = self
            return termsAndConditionsButton
        default:
            return UITableViewCell()
        }
    }
    
    internal func drawCreditCardTable(indexPath : NSIndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let paymentSearchCell = self.checkoutTable.dequeueReusableCellWithIdentifier("paymentSelectedCell") as! PaymentMethodSelectedTableViewCell
            paymentSearchCell.fillRowWithPaymentMethod(self.viewModel!.paymentMethod!, lastFourDigits: self.token!.lastFourDigits)
            ViewUtils.drawBottomLine(y : 47, width: self.view.bounds.width, inView: paymentSearchCell)
            return paymentSearchCell
        case 1:
            let installmentsCell = self.checkoutTable.dequeueReusableCellWithIdentifier("installmentSelectionCell") as! InstallmentSelectionTableViewCell
            installmentsCell.fillCell(self.payerCost!)
            return installmentsCell
        case 2 :
            let totalAmount = self.payerCost == nil ? self.preference!.getAmount() : self.payerCost!.totalAmount
            let footer = self.checkoutTable.dequeueReusableCellWithIdentifier("paymentDescriptionFooter") as! PaymentDescriptionFooterTableViewCell
            
            footer.layer.shadowOffset = CGSizeMake(0, 1)
            footer.layer.shadowColor = UIColor(red: 153, green: 153, blue: 153).CGColor
            footer.layer.shadowRadius = 1
            footer.layer.shadowOpacity = 0.6
            footer.setAmount(totalAmount, currency: CurrenciesUtil.getCurrencyFor(self.preference!.getCurrencyId()))
            return footer
        default:
            let termsAndConditionsButton = self.checkoutTable.dequeueReusableCellWithIdentifier("purchaseTermsAndConditions") as! TermsAndConditionsViewCell
            termsAndConditionsButton.paymentButton.addTarget(self, action: "confirmPayment", forControlEvents: .TouchUpInside)
            return termsAndConditionsButton
        }
    }
    
    internal func openTermsAndConditions(title: String, url : NSURL){
        let webVC = WebViewController(url: url)
        webVC.title = title
        self.navigationController!.pushViewController(webVC, animated: true)
        
    }
 
    internal func exitCheckoutFlow(){
        self.callbackCancel!()
    }
}

public class CheckoutViewModel {
    
    var paymentMethod : PaymentMethod?
    var paymentMethodSearch : PaymentMethodSearch?
    
    func isPaymentMethodSelectedCard() -> Bool {
        return self.paymentMethod != nil && !paymentMethod!.isOfflinePaymentMethod() && self.paymentMethod!._id != "account_money"
    }
    
    func numberOfSections() -> Int {
        return (self.paymentMethod != nil) ? 2 : 0
    }
    
    func isPaymentMethodSelected() -> Bool {
        return paymentMethod != nil
    }
    
    func numberOfRowsInMainSection() -> Int {
        if (self.paymentMethod == nil) {
            return 2
        } else if !isPaymentMethodSelectedCard(){
            return 3
        }
        return 4
    }
    
    func isUniquePaymentMethodAvailable() -> Bool {
        return self.paymentMethodSearch != nil && self.paymentMethodSearch!.paymentMethods.count == 1
    }
    
    func paymentMethodSearchItemSelected() -> PaymentMethodSearchItem {
        let paymentTypeIdEnum = PaymentTypeId(rawValue :self.paymentMethod!.paymentTypeId)!
        let paymentMethodSearchItemSelected : PaymentMethodSearchItem
        if paymentTypeIdEnum == PaymentTypeId.ACCOUNT_MONEY {
            paymentMethodSearchItemSelected = PaymentMethodSearchItem()
            paymentMethodSearchItemSelected.description = "Dinero en cuenta"
        } else {
            paymentMethodSearchItemSelected = Utils.findPaymentMethodSearchItemInGroups(self.paymentMethodSearch!, paymentMethodId: self.paymentMethod!._id, paymentTypeId: paymentTypeIdEnum)!
        }
        return paymentMethodSearchItemSelected
    }
}
