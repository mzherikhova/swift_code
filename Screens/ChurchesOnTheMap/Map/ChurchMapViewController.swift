//
//  ChurchMapViewController.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 29/04/2018.
//  Copyright © 2018 Globus ltd. All rights reserved.
//

import UIKit
import GoogleMaps


protocol ChurchMapDelegate: class {
    func presentChurchController(_ church: ChurchShortParameters)
}

class ChurchMapViewController: ScreenOfMenuBaseController {
    
    // MARK: - Constant
    
    fileprivate enum Constant {        
        static let defaultMapPadding: CGFloat = 80.0
        static let minDistanceToNearestMarker: Double = 500.0
    }
    
    
    
    //MARK: - Properties
    
    weak var delegate: ChurchMapDelegate?
    
    fileprivate var clusterManager: ClusterManager?
    fileprivate var clusterRenderer: ClusterRenderer?
    
    var churchesOnMap = [ChurchShortParameters]()
    /// Фильтр, для которого в последний раз были запрощены церкви. Необходим для понимания, нужно ли обновлять данные с новым фильтром.
    var churchesFilter: [Int] = ChurchFilterHelper.churchFilter()
    
    var clusterMapViewController: ClusterMapViewController?
    fileprivate var isClusterViewShowed: Bool {
        if let clusterMapViewController = self.clusterMapViewController {
            return clusterMapViewController.currentState != .hide
        }
        else {
            return false
        }
    }
    
    /// Флаг, необходимый для центрирования карты при определении местоположения
    fileprivate var isUserPositionDetected = false
    
    /// Динамическое значение местоположения пользователя от сервиса
    var dynamicLocation: Dynamic<CLLocation?> = Dynamic(nil)
    
    /// Динамическое значение местоположения пользователя, для которого запрашиваются ближайшие церкви. Ниже по иерархии чем dynamicLocation и зависит от него.
    var dynamicCoordinate: Dynamic<CLLocationCoordinate2D?> = Dynamic(nil)
    
    /// Флаг того, что объект уже наблюдает за местоположением dynamicLocation.
    fileprivate var locationMonitoringStarted: Bool = false
    
    /// Местоположение, с которого показываем карту, например, для показа точки конкретного пина. Используется при "Показать на карте".
    fileprivate(set) var startCoordinate: CLLocationCoordinate2D?
    
    /// Свойство, которое говорит об (не)активном состоянии PM
    let dynamicActive = Dynamic(false)
    
    /// Свойство, которое говорит о том, что PM находится на стадии загрузки данных
    let dynamicLoading = Dynamic(false)
    
    /// Показать экран церкви (от clusterMapViewController)
    var showChurchScreenHandler: ((Int) -> Void)?
    
    lazy fileprivate var miniActivityIndicator: ActivityIndicatorView? = {
        
        let rect = CGRect(size: CGSize(width: 15,
                                       height: 15))
        let indicator = ActivityIndicatorView(frame: rect)
        return indicator
    }()
    
    

    //MARK: - Outlets
    
    @IBOutlet weak fileprivate var mapView: GMSMapView! {
        didSet { self.configureMapView() }
    }
    
    @IBOutlet weak var zoomButtonsPanel: UIView!
    @IBOutlet weak var zoomSeparatorView: UIView!
    @IBOutlet weak var geoButtonPanel: MapControlView!

    @IBOutlet weak fileprivate var churchInfoView: UIView!
    @IBOutlet weak fileprivate var churchInfoViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak fileprivate var churchInfoViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet fileprivate var activityIndicatorContainer: UIView! {
        didSet {
            if let miniActivityIndicatorView = self.miniActivityIndicator {
                activityIndicatorContainer.addSubview(miniActivityIndicatorView)
            }
        }
    }
    
    
    
    // MARK: - IBActions
    
    @IBAction func zoomInTapped() {
        let currentPosition = self.mapView.camera
        self.mapView.animate(toZoom: currentPosition.zoom + 1)
    }
    
    @IBAction func zoomOutTapped() {
        let currentPosition = self.mapView.camera
        self.mapView.animate(toZoom: currentPosition.zoom - 1)
    }
    
    @IBAction func showUserLocationTapped() {
        
        let locationService = LocationService.instance
        
        // Если доступ к геолокации еще не разрешен, то подпишемся на изменение координат,
        // чтобы получить местоположение, когда пользователь включит геолокацию
        if !locationService.locationServiceEnabledDynamic.value {
            locationService.lastUpdateDynamic.bind(self, action: { [weak self] (location) in
                guard let strongSelf = self
                    else { return }
                strongSelf.showUserLocationOnMap(location)
                locationService.lastUpdateDynamic.unbind(strongSelf)
            })
        }
        
        LocationPermissionHelper.showLocationAuthIfNeeded(target: self) { [weak self](answer) in
            if answer {
                self?.showUserLocationOnMap()
            }
        }
    }
    
    @objc func updateUserLocation() {
        let locationService = LocationService.instance
        if locationService.locationServiceEnabledDynamic.value {
            self.showUserLocationOnMap()
        }
    }
    
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "churchMapTitle".localized()
        
        setupTheme()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateUserLocation),
                                               name: Notification.Name.UIApplicationDidBecomeActive,
                                               object: nil)
        showPermissionAlertIfNeeded()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        self.dynamicLocation.unbind(self)
        self.dynamicCoordinate.unbind(self)
        
        self.dynamicActive.unbind(self)
        self.dynamicLoading.unbind(self)
        
        stopMonitoringLocation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //TODO: После возврата с экрана церкви иногда сбрасывается камера на текущее местоположение.
        super.viewWillAppear(animated)
        if ChurchFilterHelper.didChurchFilterChanged(oldFilters: churchesFilter) {
            churchesFilter = ChurchFilterHelper.churchFilter()
            unselectChurch()
            hideClusterViewIfNeeded()
            obtainData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //TODO: После возврата с экрана церкви иногда сбрасывается камера на текущее местоположение.
        super.viewDidAppear(animated)
        self.dynamicActive.value = true
        miniActivityIndicator?.animating = miniActivityIndicator?.animating ?? false
    }
    
    
    
    // MARK: - Configure
    
    override func setupTheme() {
        super.setupTheme()
        let config = ThemeManager.shared.currentConfig
        self.view.backgroundColor = config.common.bgColor
        
        let navbar = navigationController?.navigationBar
        navbar?.barTintColor = config.navbar.backgroundColor
        navbar?.titleTextAttributes = [NSFontAttributeName: UIFont.appFont(16),
                                       NSForegroundColorAttributeName: config.navbar.titleColor]
        self.navigationItem.leftBarButtonItem?.tintColor = config.navbar.iconsTintColor
        
        self.zoomButtonsPanel.backgroundColor = config.common.bgColor
        self.geoButtonPanel.backgroundColor = config.common.bgColor
        
        self.clusterMapViewController?.setupTheme()
        
        let theme = ThemeManager.shared.currentTheme
        switch theme {
        case .light:
            self.mapView.mapStyle = nil
            self.mapView.backgroundColor = theme.config.common.bgColor
            self.zoomSeparatorView.backgroundColor = UIColor("EAEAEA")
            self.zoomButtonsPanel.layer.shadowOpacity = 0.1
            self.geoButtonPanel.layer.shadowOpacity = 0.1
            break
        case .dark:
            let nightURL = Bundle.main.url(forResource: "mapstyle-night", withExtension: "json")
            let nightStyle = try! GMSMapStyle(contentsOfFileURL: nightURL!)
            self.mapView.mapStyle = nightStyle
            self.mapView.backgroundColor = theme.config.common.bgColor
            self.zoomSeparatorView.backgroundColor = UIColor("3B3D3E")
            self.zoomButtonsPanel.layer.shadowOpacity = 0.5
            self.geoButtonPanel.layer.shadowOpacity = 0.5
            break
        }
    }
    
    fileprivate func configureFilterIfNeeded() {
        if !ApplicationSettingsService.instance.didChurchFilterDefaultSettings {
            ChurchFilterHelper.saveFilter(selectedConfessions: [true, true, true])
            ApplicationSettingsService.instance.didChurchFilterDefaultSettings = true
        }
    }
    
    
    
    // MARK: - Public

    /// Метод для инициализации
    func configure(startCoordinate: CLLocationCoordinate2D? = nil) {
        
        configureFilterIfNeeded()

        // Предотвращаем сброс фокуса с выбранной церкви
        if let _ = startCoordinate {
            isUserPositionDetected = true
        }
        self.startCoordinate = startCoordinate

        listenForLocationIfAllowed()

        self.showChurchScreenHandler = { [weak self] (churchId) in
            guard
                let strongSelf = self
            else { return }
            
            let selectedMarker = strongSelf.clusterRenderer?.selectedMarker as? ChurchMarker
            if let selectedChurch = strongSelf.churchesOnMap.first(where: {
                $0.id == selectedMarker?.model.entityId }) {
                strongSelf.delegate?.presentChurchController(selectedChurch)
            }
        }

        self.dynamicLocation
            .bindAndFire(self, action: { [weak self] (location) in
                self?.dynamicCoordinate.value = location?.coordinate

                guard
                    let strongSelf = self,
                    let location = location
                else { return }
                if !strongSelf.isUserPositionDetected {
                    strongSelf.showUserLocationOnMap(location)
                    strongSelf.isUserPositionDetected = true
                    strongSelf.obtainData()
                }
            })

        self.dynamicLoading.bind(self, action: { [weak self] (isLoading) in
            if !isLoading {
                self?.reloadClusters()
            }

            guard
                let strongSelf = self
            else { return }
            strongSelf.miniActivityIndicator?.animating = isLoading
        })

        // Пробуем обновить церкви при первом запуске.
        // Вызываем перед dynamicActive,
        // чтобы не заблокировалось dynamicLoading от updateData()
        self.obtainData()

        self.dynamicActive.bind(self) { [weak self] (isActive) in
            if isActive {
                // Каждый раз, когда показано на экране - обновляем из БД.
                self?.updateData()
                guard
                    self?.dynamicLocation.value != nil
                else {
                    self?.tryToListenLocation()
                    return
                }
            }
        }
    }
    

    
    // MARK: - Private
    
    /// Запросить церкви из сервиса
    fileprivate func obtainData() {
        
        unselectChurch()
        
        guard !self.dynamicLoading.value else { return }
        
        if !shouldUpdateData() {
            updateData()
        } else {
            dynamicLoading.value = true
            
            updateData(forced: true)
            
            // Если доступ к местоположению запрещен,
            // то нужно запросить с default-координатами Москвы
            var userCoordinate: CLLocationCoordinate2D = GlobalConstants
                .GoogleMap.Defaults.moscowCoordinate
            if let dynamicCoordinate = self.dynamicCoordinate.value {
                userCoordinate = dynamicCoordinate
            }
            
            let latitude = userCoordinate.latitude
            let longitude = userCoordinate.longitude
            //NOTE: нужно использовать churchesFilter
            //let filter = ChurchFilterHelper.churchFilter()
            let filter = churchesFilter
            
            ChurchAPIManager.shared.churches { [weak self] (response) in
                
                self?.dynamicLoading.value = false
                
                switch response {
                case let .success(data):
                    guard
                        let strongSelf = self
                        else { return }
                    
                    let churches = data
                    ServicesDBManager.shared.churches.createUpdate(churches: churches)
                    strongSelf.updateData()
                    ApplicationSettingsService.instance.cacheUpdateDateForChurchesOnMap = Date()
                    
                case let .failure(error):
                    ErrorHandler.handle(error)
                }
            }
        }
    }

    /// Загрузить церкви из БД
    fileprivate func updateData(forced: Bool = false) {
        
        if !forced {
            guard !self.dynamicLoading.value else { return }
            dynamicLoading.value = true
        }
        
        //let filter = ChurchFilterHelper.churchFilter()
        let filter = churchesFilter
        ServicesDBManager.shared.churches.churchesByConfession(filter) { (churches) in
            self.churchesOnMap = churches
            if !forced {
                self.dynamicLoading.value = false
            }
            self.reloadClusters()
        }
    }
    
    fileprivate func showPermissionAlertIfNeeded() {
        if !ApplicationSettingsService.instance.didDisplayLocationPermission {
            showUserLocationTapped()
            ApplicationSettingsService.instance.didDisplayLocationPermission = true
        }
    }
}



// MARK: - MapView

extension ChurchMapViewController {
    
    func configureMapView() {
        
        // Конфигурируем настройки Map View
        if let _ = self.dynamicCoordinate.value {
            self.mapView.isMyLocationEnabled = true
        }

        // Конфигурируем начальное положение на карте
        if let startCoordinate = self.startCoordinate {

            self.mapView.camera =
                GMSCameraPosition.camera(
                    withTarget: startCoordinate,
                    zoom: GlobalConstants.GoogleMap.Defaults.nearestZoom)

            self.configureClastersHelpers(withMapView: self.mapView)
        }
        else {
            if let coordinate = self.dynamicCoordinate.value {
                self.mapView.camera =
                    GMSCameraPosition.camera(
                        withTarget: coordinate,
                        zoom: GlobalConstants.GoogleMap.Defaults.nearZoom)
            } else {
                self.mapView.camera =
                    GMSCameraPosition.camera(
                        withTarget: GlobalConstants.GoogleMap.Defaults.moscowCoordinate,
                        zoom: GlobalConstants.GoogleMap.Defaults.startZoom)
            }
            self.configureClastersHelpers(withMapView: self.mapView)
        }

        let currentTheme = ThemeManager.shared.currentTheme
        switch currentTheme {
        case .light:
            self.mapView.mapStyle = nil
            self.mapView.backgroundColor = currentTheme.config.common.bgColor
            break
        case .dark:
            let nightURL = Bundle.main.url(forResource: "mapstyle-night", withExtension: "json")
            let nightStyle = try! GMSMapStyle(contentsOfFileURL: nightURL!)
            self.mapView.mapStyle = nightStyle
            self.mapView.backgroundColor = currentTheme.config.common.bgColor
            break
        }
    }
    
    func configureClastersHelpers(withMapView mapView: GMSMapView) {
        
        let renderer = ClusterRenderer(mapView: mapView)
        
        self.clusterRenderer = renderer
        self.clusterManager = ClusterManager(
            mapView: mapView,
            renderer: renderer)
        
        self.clusterManager?.setDelegate(nil, mapDelegate: self)
        
        reloadClusters()
    }
    
    fileprivate func reloadClusters() {
        if churchesOnMap.count > 0 {
            self.clusterManager?.reloadClusters(with: churchesOnMap)
        } else {
            self.clusterManager?.reloadClusters(with: [])
        }
    }
}



// MARK: - GMSMapViewDelegate

extension ChurchMapViewController: GMSMapViewDelegate {
    
    
    // Тап на "Что-то" на карте
    
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker)
        -> Bool {
            
            if let marker = marker as? MapMarker {
                handleTapOn(marker)
                return true
            } else {
                return false
            }
    }
    
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        
        unselectChurch()
        hideClusterViewIfNeeded()
    }
    
    
    // Обработчики нажатий
    
    fileprivate func handleTapOn(_ marker: MapMarker) {
        
        if let cluster = marker as? ClusterMarker {
            handleTapOnMarker(cluster)
        }
        else if let church = marker as? ChurchMarker {
            handleTapOnMarker(church)
        }
    }
    
    fileprivate func handleTapOnMarker(_ marker: ChurchMarker) {
        
        unselectChurch()
        hideClusterViewIfNeeded()
        
        animateMap(to: marker.position)
        persistMarkerAsSelected(marker)
        
        guard
            let churchModel = marker.userData as? Church
        else { return }
        
        showClustersView(withChurches: [churchModel])
    }
    
    fileprivate func handleTapOnMarker(_ marker: ClusterMarker) {
        
        unselectChurch()
        let camera = mapView.camera
        
        if camera.zoom < GlobalConstants.GoogleMap.Defaults.nearestZoom {
            hideClusterViewIfNeeded()
            
            // Если кластер не раскрывается (организации в одной точке)
            if marker.isAllItemsWithEqualPositions() {
                if camera.zoom < GlobalConstants.GoogleMap.Defaults.nearZoom {
                    animateMap(to: marker.position, zoom: GlobalConstants.GoogleMap.Defaults.nearZoom)
                } else {
                    animateMap(to: marker.position)
                }
                selectClusterMarker(marker)
            }
            else {
                let positions = marker.cluster.items.map({ $0.position })
                animateMap(withPositions: positions)
            }
        }
        else {
            animateMap(to: marker.position)
            selectClusterMarker(marker)
        }
    }
    
    fileprivate func selectClusterMarker(_ marker: ClusterMarker) {
        guard let churches = marker.cluster.items as? [Church]
            else { return }

        persistMarkerAsSelected(marker)
        showClustersView(withChurches: churches)
    }
    
    fileprivate func persistMarkerAsSelected(_ marker: GMSMarker) {
        
        guard
            let marker = marker as? MapMarker
        else { return }

        selectMarker(marker)
    }
    
    func selectMarker(_ marker: MapMarker?) {
        clusterRenderer?.selectedMarker = marker
    }
    
    fileprivate func unselectChurch() {
        
        // Сбрасываем выбранную церковь
        selectMarker(nil)
    }
    
    // Работа с камерой MapView
    
    func animateMapWithZoom(to position: CLLocationCoordinate2D) {
        
        let camera = mapView.camera
        if camera.zoom < GlobalConstants.GoogleMap.Defaults.nearestZoom {
            let zoom = camera.zoom + 2.0
            mapView.animate(to:
                GMSCameraPosition(
                    target: position,
                    zoom: zoom,
                    bearing: camera.bearing,
                    viewingAngle: camera.viewingAngle))
        }
        else {
            mapView.animate(to: camera)
        }
    }
    
    func animateMap(to position: CLLocationCoordinate2D, zoom: Float? = nil) {
        
        let camera = mapView.camera
        let zoom = zoom ?? camera.zoom
        mapView.animate(to:
            GMSCameraPosition(
                target: position,
                zoom: zoom,
                bearing: camera.bearing,
                viewingAngle: camera.viewingAngle))
    }
    
    func animateMap(withPositions positions: [CLLocationCoordinate2D]) {
        
        // считаем крайние точки GMSCoordinateBounds
        var bounds = GMSCoordinateBounds()
        for position in positions {
            bounds = bounds.includingCoordinate(position)
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: Constant.defaultMapPadding)
        mapView.animate(with: update)
    }
    
    
    // Центрирование камеры на местоположении пользователя
    
    func showUserLocationOnMap(_ location: CLLocation? = nil) {
        
        guard let _ = self.mapView else { return }
        
        var coordinateForCamera: CLLocationCoordinate2D?
        
        // Локация отмечена на карте
        if self.mapView.isMyLocationEnabled,
            let coordinate = location?.coordinate ?? self.mapView.myLocation?.coordinate {
            
            coordinateForCamera = coordinate
        }
        else {
            // локация не включена, но координаты доступны в модели
            self.mapView.isMyLocationEnabled = true
            
            guard
                let coordinate = self.dynamicCoordinate.value
            else { return }
            
            coordinateForCamera = coordinate

        }
        
        if let coordinateForCamera = coordinateForCamera {
            
            let position =
                GMSCameraPosition.camera(
                    withTarget: coordinateForCamera,
                    zoom: GlobalConstants.GoogleMap.Defaults.nearZoom)
            mapView.animate(to: position)
        }
    }
    
    // MARK: - Clusters View
    
    func showClustersView(withChurches churches: [Church]) {
        
        if clusterMapViewController == nil {
            
            let viewController = ClusterMapViewController()
            self.clusterMapViewController = viewController
            
            addChildViewController(viewController)
            churchInfoView.addSubview(viewController.view)
            
            viewController.view.fillView(insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
            viewController.didMove(toParentViewController: self)
            
            viewController.actionForTapOnChurchView = { [weak self] (churchId) in
                guard
                    let strongSelf = self
                else { return }

                strongSelf.showChurchScreenHandler?(churchId)
            }
            
            viewController.unselectChurchAction = { [weak self] in
                self?.unselectChurch()
            }
        }
        
        // Update current distane
        // Если доступ к местоположению запрещен,
        // то нужно запросить с default-координатами Москвы
        var userCoordinate: CLLocationCoordinate2D = GlobalConstants
            .GoogleMap.Defaults.moscowCoordinate
        if let dynamicCoordinate = self.dynamicCoordinate.value {
            userCoordinate = dynamicCoordinate
        }
        clusterMapViewController?.reload(with: churches,
                                         userLatitude: userCoordinate.latitude,
                                         userLongitude: userCoordinate.longitude)
        clusterMapViewController?.show()
    }
    
    func hideClusterViewIfNeeded() {
        
        if !isClusterViewShowed { return }
        
        clusterMapViewController?.hide()
    }
}



// MARK: - Location monitoring

extension ChurchMapViewController {
    
    func startMonitoringLocation()
    {
        self.locationMonitoringStarted = true
        
        let locationService = LocationService.instance
        
        locationService.addListener(
            observer: self,
            action: { [weak self] (location) in
                
                guard
                    let currentLocation = location,
                    let strongSelf = self
                    else { return }
                
                strongSelf.dynamicLocation.value = currentLocation
        })
    }
    
    func stopMonitoringLocation() {
        self.locationMonitoringStarted = false
        LocationService.instance.removeListener(observer: self)
    }
    
    var locationIsEnabled: Bool {
        return LocationService.instance.locationServiceEnabledDynamic.value
    }
    
    func listenForLocationIfAllowed() {
        if locationIsEnabled {
            startMonitoringLocation()
        }
    }
    
    func tryToListenLocation() {
        guard !locationMonitoringStarted else { return }
        
        if locationIsEnabled {
            startMonitoringLocation()
        }
    }
}



// MARK: - Cache

extension ChurchMapViewController {

    /// Обновляем если последний кэш более часа назад
    fileprivate func shouldUpdateData() -> Bool {

        guard let lastUpdate = ApplicationSettingsService.instance.cacheUpdateDateForChurchesOnMap
            else { return true }

        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let components =
            (calendar as NSCalendar)
                .components(
                    NSCalendar.Unit.hour,
                    from: lastUpdate,
                    to: Date(),
                    options: NSCalendar.Options(rawValue: 0))
        let isMoreThanOneHour = components.hour! > 0

        return isMoreThanOneHour
    }
}
