angular.module('ngTokenAuthTestApp')
  .controller 'StyleGuideCtrl', ($scope) ->
    # Generic content
    $scope.fakeListContent = _.map [0...3], ->
      Faker.Lorem.sentences(1)

    $scope.fakeUsers = _.map [0...6], ->
      firstName: Faker.Name.firstName()
      lastName:  Faker.Name.lastName()
      email:     Faker.Internet.email()

    # Modals
    $scope.modal =
      title:   Faker.Lorem.sentence(4)
      content: Faker.Lorem.paragraph(1)

    # Asides
    $scope.aside =
      title:   Faker.Lorem.sentence(4)
      content: Faker.Lorem.sentence(4)

    # Alerts
    $scope.alert =
      title:   Faker.Lorem.sentence(4)
      content: Faker.Lorem.sentence(10)
      type:    'info'

    # Buttons
    $scope.buttons =
      toggle: false
      checkbox:
        left:   false
        middle: false
        right:  false
      radio: 2

    # Select boxes
    $scope.selectedIcon = ''
    $scope.selectedIcons = []
    $scope.icons = [
      {value: 'Gear',   label: '<i class="fa fa-gear"></i> Gear'}
      {value: 'Globe',  label: '<i class="fa fa-globe"></i> Globe'}
      {value: 'Heart',  label: '<i class="fa fa-heart"></i> Heart'}
      {value: 'Camera', label: '<i class="fa fa-camera"></i> Camera'}
    ]

    # Datepickers
    $scope.selectedDate         = "2014-04-01T16:49:16.152Z"
    $scope.selectedDateAsNumber = 509414400000
    $scope.fromDate             = undefined
    $scope.untilDate            = undefined

    # Timepickers
    $scope.time                 = "1970-01-01T16:30:00.000Z"
    $scope.selectedTimeAsNumber = 36000000
    $scope.sharedDate           = "2014-04-01T16:00:16.160Z"

    # Tooltips
    $scope.tooltip =
      title:   "Multi-line <br />Tooltip <i>with</i> <b>HTML</b>"
      checked: false

    # Popovers
    $scope.popover =
      title:   "Title"
      content: "This<br />is a multiline <b>HTML</b> message!"
      saved:   true


    $scope.dropdown = [
      {
        text: '<i class="fa fa-download"></i>&nbsp;Another action'
        href: '#anotherAction'
      }, {
        text: '<i class="fa fa-globe"></i>&nbsp;Display an alert'
        click: '$alert("Oh fuck!")'
      }, {
        divider: true
      }, {
        text: '<i class="fa fa-download"></i>&nbsp;Separated link'
        href: '#separatedLink'
      }
    ]

    $scope.selectedState = ''
    $scope.states = [
      "Alabama","Alaska","Arizona","Arkansas","California","Colorado",
      "Connecticut","Delaware","Florida","Georgia","Hawaii","Idaho",
      "Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana","Maine",
      "Maryland","Massachusetts","Michigan","Minnesota","Mississippi",
      "Missouri","Montana","Nebraska","Nevada","New Hampshire","New Jersey",
      "New Mexico","New York","North Dakota","North Carolina","Ohio",
      "Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina",
      "South Dakota","Tennessee","Texas","Utah","Vermont","Virginia",
      "Washington","West Virginia","Wisconsin","Wyoming"
    ]
