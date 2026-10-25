import 'package:flutter/foundation.dart';

import '../../data/mock_itinerary.dart';
import '../../data/models/itinerary_models.dart';

class ItineraryController extends ChangeNotifier {
  ItineraryController({ItineraryPlan? plan})
    : _plan = plan ?? mockItineraryPlan,
      _confirmed = plan?.status == ItineraryStatus.finalized;

  ItineraryPlan _plan;
  bool _confirmed = false;

  ItineraryPlan get plan => _plan;
  bool get confirmed => _confirmed;
  ItineraryStatus get status =>
      _confirmed ? ItineraryStatus.finalized : _plan.status;
  int get reviewedCount => _plan.reviewedCount;
  int get memberCount => _plan.members.length;
  bool get allMembersReviewed => _plan.allReviewed;

  void toggleCurrentUserReviewed() {
    if (_confirmed) return;

    final index = _plan.members.indexWhere(
      (member) => member.isCurrentUser,
    );
    if (index == -1) return;

    final members = List<ItineraryMember>.of(_plan.members);
    members[index] = members[index].copyWith(
      reviewed: !members[index].reviewed,
    );

    _plan = _plan.copyWith(members: members);
    notifyListeners();
  }

  void confirm() {
    if (_confirmed || !allMembersReviewed) return;

    _confirmed = true;
    _plan = _plan.copyWith(status: ItineraryStatus.finalized);
    notifyListeners();
  }

  void reset() {
    _plan = mockItineraryPlan;
    _confirmed = false;
    notifyListeners();
  }
}
