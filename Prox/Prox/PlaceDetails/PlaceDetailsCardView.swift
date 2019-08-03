/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SnapKit
import ScrollingCardView

private let margin: CGFloat = 24
private let bottomMargin: CGFloat = 20

protocol PlaceDetailsCardDelegate: class {
    func placeDetailsCardView(cardView: PlaceDetailsCardView, heightDidChange newHeight: CGFloat)
    func placeDetailsCardView(cardView: PlaceDetailsCardView, directionsRequestedTo: Place, by: MKDirectionsTransportType)
}

class PlaceDetailsCardView: ScrollingCardView {

    private(set) var place: Place

    weak var delegate: PlaceDetailsCardDelegate?

    // HACK: The code was originally written assuming there is an image carousel per card view so I
    // put the carousel in the card view instance. A better implementation would have one image carousel
    // for the PlaceDetailViewController (or 2 so we can cross-fade between them when switching place
    // cards). If we want to preserve the current behavior, this implementation would need to keep track of
    // and restore which image the user was last looking at for this particular card.
    let imageCarousel: PlaceDetailsImageCarousel

    private lazy var containingStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews:[self.eventHeader,
                                                 self.labelContainer,
                                                 self.iconInfoViewContainer,
                                                 self.reviewViewContainer,
                                                 self.eventDescriptionView,
                                                 self.wikiDescriptionView,
                                                 self.tripAdvisorDescriptionView,
                                                 self.yelpDescriptionView
            ])
        view.axis = .vertical
        view.spacing = margin

        view.layoutMargins = UIEdgeInsets(top: margin, left: 0,
                                          bottom: bottomMargin, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private func setContainingStackViewMargins(isTopMarginPresent: Bool) {
        // Margins initialized in lazy init.
        containingStackView.layoutMargins = UIEdgeInsets(top: isTopMarginPresent ? margin : 0, left: 0,
                                                         bottom: bottomMargin, right: 0)
    }

    private let eventHeader: PlaceDetailsEventHeader = {
        let view = PlaceDetailsEventHeader()
        view.isHidden = true // view depends on top margin, which exists by default
        return view
    }()

    // MARK: Outer views.
    // TODO: accessibility labels (and parent view)
    // TODO: set line height on all text. http://stackoverflow.com/a/5513730
    private lazy var labelContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.titleLabel,
                                                  self.categoryLabel,
                                                  self.urlLabel])
        view.axis = .vertical
        view.spacing = 4

        view.layoutMargins = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private lazy var iconInfoViewContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.travelTimeView,
                                                  self.hoursView])
        view.axis = .horizontal
        view.distribution = .fillEqually

        view.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    // Ideally we also use a UIStackView but the review dots stretched too
    // far across the screen and it was faster to do it this way.
    private lazy var reviewViewContainer: UIStackView = {
        let reviewStackView = UIStackView(arrangedSubviews: [self.yelpReviewView,
                                          self.tripAdvisorReviewView])
        reviewStackView.layoutMargins = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        reviewStackView.spacing = 25
        reviewStackView.axis = .horizontal
        reviewStackView.isLayoutMarginsRelativeArrangement = true
        reviewStackView.distribution = .fillEqually
        return reviewStackView
    }()

    // MARK: Inner views
    private lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardPrimaryText
        view.font = Fonts.detailsViewTitleText
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        return view
    }()

    private lazy var categoryLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardPrimaryText
        view.font = Fonts.detailsViewCategoryText
        return view
    }()

    private lazy var urlLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardLinkText
        view.font = Fonts.detailsViewCategoryText
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var travelTimeView = PlaceDetailsTravelTimesView()

    private lazy var hoursView: PlaceDetailsIconInfoView = {
        let view = PlaceDetailsIconInfoView(enableForwardArrow: false)
        view.iconView.image = UIImage(named: "icon_times")
        return view
    }()


    private lazy var yelpReviewView: ReviewContainerView = {
        let view = ReviewContainerView(getStarsFromScore: ProviderStarImage.yelp(forScore:))
        view.reviewSiteLogo.image = UIImage(named: "logo_yelp")
        return view
    }()

    private lazy var tripAdvisorReviewView: ReviewContainerView = {
        let view = ReviewContainerView(getStarsFromScore: ProviderStarImage.tripAdvisor(forScore:))
        view.reviewSiteLogo.image = UIImage(named: "logo_ta")
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var tripAdvisorDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "Highlights from TripAdvisor",
                                               icon: UIImage(named: "logo_TA_small"),
                                               type: DetailType.tripadvisor,
                                               expanded: false)

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on TripAdvisor", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    }()

    private lazy var wikiDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "The top line from Wikipedia",
                                        icon: UIImage(named: "logo_wikipedia"),
                                        type: DetailType.wikipedia,
                                        expanded: false)

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on Wikipedia", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    }()

    private lazy var yelpDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "The latest from Yelp",
                                                               icon: UIImage(named: "logo_yelp_small"),
                                                               type: DetailType.yelp,
                                                               expanded: false)
        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on Yelp", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    } ()

    private lazy var eventDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "Event details",
                                               icon: nil,
                                               type: DetailType.event,
                                               expanded: false)
        return view
    } ()

    private var collapsedReviewConstraints: [Constraint]!

    init(place: Place, userLocation: CLLocation?) {
        self.place = place
        self.imageCarousel = PlaceDetailsImageCarousel(place: place)
        super.init()
        setupViews()
        setupShadow()
        updateUI(forPlace: place, withUserLocation: userLocation)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupShadow() {
        layer.shadowOffset = Style.cardViewShadowOffset
        layer.shadowRadius = Style.cardViewShadowRadius
        layer.shadowOpacity = Style.cardViewShadowOpacity
    }

    private func setupViews() {
        backgroundColor = Colors.detailsViewCardBackground
        cornerRadius = Style.cardViewCornerRadius
        contentView = containingStackView

        containingStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        collapsedReviewConstraints = reviewViewContainer.snp.prepareConstraints { make in
            make.height.equalTo(0)
        }

        setupGestureRecognizers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewSize()
    }

    // TODO: when else can we call this? layoutSubviews is called when we scroll and we don't want to calculate all this each time...
    private func updateViewSize() {
        delegate?.placeDetailsCardView(cardView: self, heightDidChange: bounds.height)
    }

    func updateUI(forPlace place: Place, withUserLocation userLocation: CLLocation?) {
        self.place = place
        imageCarousel.place = place

        // Labels will gracefully collapse on nil.
        titleLabel.text = place.name
        categoryLabel.text = PlaceUtilities.getString(forCategories: place.categories.names)
        updateURLText(place.website)
        updateHoursUI(forPlace: place, with: place.hours)
        updateEventUI(forPlace: place)

        let viewDescriptions: [(view: PlaceDetailsDescriptionView, description: String?)] = [
            (eventDescriptionView, place.customProvider?.description),
            (wikiDescriptionView, place.wikipediaProvider?.description),
            (tripAdvisorDescriptionView, place.tripAdvisorProvider?.description),
            (yelpDescriptionView, place.yelpProvider.description),
        ]

        var didExpand = false
        for viewDescription in viewDescriptions {
            updateDescriptionViewUI(forText: viewDescription.description, onView: viewDescription.view, expanded: !didExpand)
            didExpand = didExpand || viewDescription.description != nil
        }

        PlaceUtilities.updateTravelTimeUI(fromPlace: place, toLocation: userLocation, forView: travelTimeView)

        PlaceUtilities.updateReviewUI(fromProvider: place.yelpProvider, onView: yelpReviewView)
        PlaceUtilities.updateReviewUI(fromProvider: place.tripAdvisorProvider, onView: tripAdvisorReviewView)

        let collapsed = (place.totalReviewCount == 0)
        reviewViewContainer.isHidden = collapsed
        collapsedReviewConstraints.setAllActive(collapsed)
    }

    private func updateEventUI(forPlace place: Place) {
        eventHeader.isHidden = !place.isEvent
        setContainingStackViewMargins(isTopMarginPresent: !place.isEvent)
    }

    private func updateURLText(_ url: URL?) {
        guard let url = url?.absoluteString else {
            urlLabel.text = nil
            return
        }

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: url, attributes: underlineAttribute)
        urlLabel.attributedText = underlineAttributedString
    }

    private func updateHoursUI(forPlace place: Place, with hours: OpenHours?) {
        // HACK: For hand-curated Discover data, places open 24hrs have nil hours data so we update
        // their strings here. I didn't write a solution to handle *all* places open 24hrs because
        // the open hours code is complicated and I didn't have time.
        if place.id.hasPrefix(AppConstants.testPrefixDiscover),
                hours == nil {
            hoursView.iconView.isHidden = false
            hoursView.isPrimaryTextLabelHidden = false
            hoursView.primaryTextLabel.text = Strings.detailsView.open
            hoursView.secondaryTextLabel.text = Strings.detailsView.twentyFourHours
            hoursView.secondaryTextLabel.numberOfLines = 1
            return
        }

        guard let (primaryText, secondaryText) = getStringsForOpenHours(hours, forDate: Date(), isEvent: place.isEvent) else {
            hoursView.iconView.isHidden = true
            hoursView.isPrimaryTextLabelHidden = true
            hoursView.secondaryTextLabel.text = "Check listing\nfor hours"
            hoursView.secondaryTextLabel.numberOfLines = 2
            return
        }

        hoursView.iconView.isHidden = false
        hoursView.isPrimaryTextLabelHidden = false
        hoursView.primaryTextLabel.text = primaryText.capitalized
        hoursView.secondaryTextLabel.text = secondaryText
        hoursView.secondaryTextLabel.numberOfLines = 1
    }

    private func updateDescriptionViewUI(forText text: String?, onView view: PlaceDetailsDescriptionView, expanded: Bool) {
        view.isHidden = text == nil ? true : false
        view.descriptionLabel.text = text
        view.setExpandableView(isExpanded: expanded)
    }

    private func getStringsForOpenHours(_ openHours: OpenHours?, forDate date: Date, isEvent: Bool) -> (primary: String, secondary: String)? {
        guard let openHours = openHours else {
            // if hours is nil, we assume this place has no listed hours (e.g. beach).
            return nil
        }

        let now = Date()
        if isEvent {
            return openHours.getEventTimeText(forToday: now)
        } else if openHours.isOpen(atTime: now),
            let closingTime = openHours.closingTime(forTime: now) {
            return ("Open", "Until \(closingTime)")
        } else if let openingTime = openHours.nextOpeningTime(forTime: now) {
            return ("Closed", "Until \(openingTime)")
        }

        return nil
    }

    // MARK: gesture recognizers
    private func setupGestureRecognizers() {
        tripAdvisorDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapDescriptionView(gestureRecognizer:))))
        wikiDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapDescriptionView(gestureRecognizer:))))
        yelpDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapDescriptionView(gestureRecognizer:))))
        eventDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapDescriptionView(gestureRecognizer:))))

        urlLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openPlaceURL(gestureRecognizer:))))

        yelpReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openYelpReview(gestureRecognizer:))))
        tripAdvisorReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openTripAdvisorReview(gestureRecognizer:))))

        travelTimeView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openDirections(gestureRecgonizer:))))

        wikiDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openWikipediaURL(gestureRecognizer:))))
        tripAdvisorDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openReadMoreTripAdvisorLink(gestureRecgonizer:))))
        yelpDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openReadMoreYelpLink(gestureRecognizer:))))
    }

    @objc private func didTapDescriptionView(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended,
            let descriptionView = gestureRecognizer.view as? PlaceDetailsDescriptionView else {
                return
        }

        descriptionView.didTap()
        self.layoutIfNeeded()
    }

    /// Convenience function for calling into `OpenInHelper.open(url:)`.
    private func open(optURL url: URL?, analyticsStr: String, errStr: String) {
        guard let url = url else { return }
        OpenInHelper.open(url: url, analyticsStr: analyticsStr, errStr: errStr)
    }

    @objc private func openPlaceURL(gestureRecognizer: UITapGestureRecognizer) {
        open(optURL: place.website, analyticsStr: AnalyticsEvent.WEBSITE, errStr: "unable to open web address")
    }

    @objc private func openYelpReview(gestureRecognizer: UITapGestureRecognizer) {
        open(optURL: place.yelpProvider.url, analyticsStr: AnalyticsEvent.YELP, errStr: "unable to open yelp review")
    }

    @objc private func openReadMoreYelpLink(gestureRecognizer: UITapGestureRecognizer) {
        open(optURL: place.yelpProvider.url, analyticsStr: AnalyticsEvent.YELP_READ, errStr: "unable to open yelp review")
    }

    @objc private func openTripAdvisorReview(gestureRecognizer: UITapGestureRecognizer) {
        open(optURL: place.tripAdvisorProvider?.url, analyticsStr: AnalyticsEvent.TRIPADVISOR, errStr: "unable to open trip advisor review")
    }

    @objc private func openReadMoreTripAdvisorLink(gestureRecgonizer: UITapGestureRecognizer) {
        open(optURL: place.tripAdvisorProvider?.url, analyticsStr: AnalyticsEvent.TRIPADVISOR_READ, errStr: "unable to open trip advisor review")
    }

    @objc private func openWikipediaURL(gestureRecognizer: UITapGestureRecognizer) {
        open(optURL: place.wikipediaProvider?.url, analyticsStr: AnalyticsEvent.WIKIPEDIA_READ, errStr: "unable to open wikipedia review")
    }

    @objc private func openDirections(gestureRecgonizer: UITapGestureRecognizer) {
        guard let transportString = travelTimeView.secondaryTextLabel.text else { return }
        let transportType = transportString == "Walking" ? MKDirectionsTransportType.walking : MKDirectionsTransportType.automobile // TODO: fragile - change to enum.

        delegate?.placeDetailsCardView(cardView: self, directionsRequestedTo: place, by: transportType)
    }
}
