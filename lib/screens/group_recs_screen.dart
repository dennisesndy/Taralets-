import 'package:flutter/material.dart';

class GroupRecsScreen extends StatefulWidget {
  final String tripId;

  const GroupRecsScreen({super.key, required this.tripId});

  @override
  State<GroupRecsScreen> createState() => _GroupRecsScreenState();
}

class _GroupRecsScreenState extends State<GroupRecsScreen> {
  final List<Map<String, dynamic>> _recommendedPlaces = [
    {
      'id': 'plc_1',
      'name': 'Rizal Park Monument',
      'category': 'Historical',
      'match_score': 94.2,
      'approx_budget': 0.0,
      'rating': 4.6,
      'distance_km': 1.2,
    },
    {
      'id': 'plc_2',
      'name': 'Fort Santiago & Intramuros',
      'category': 'Culture & Heritage',
      'match_score': 89.5,
      'approx_budget': 75.0,
      'rating': 4.7,
      'distance_km': 2.1,
    },
    {
      'id': 'plc_3',
      'name': 'National Museum of Fine Arts',
      'category': 'Museum',
      'match_score': 83.0,
      'approx_budget': 0.0,
      'rating': 4.8,
      'distance_km': 1.8,
    },
  ];

  final Set<String> _selectedPlaceIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPlaceIds.contains(id)) {
        _selectedPlaceIds.remove(id);
      } else {
        _selectedPlaceIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Places'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.shade50,
            child: Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scored using Chang et al. (2025) multi-factor model: preferences, budget, hours, and travel proximity.',
                    style: TextStyle(fontSize: 12.5, color: Colors.blueGrey, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _recommendedPlaces.length,
              itemBuilder: (context, index) {
                final place = _recommendedPlaces[index];
                final isSelected = _selectedPlaceIds.contains(place['id']);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${place['match_score'].toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    title: Text(
                      place['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${place['category']} • ₱${place['approx_budget'].toInt()} • ${place['distance_km']} km away',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(place['id']),
                    ),
                    onTap: () => _toggleSelection(place['id']),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                )
              ],
            ),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedPlaceIds.isEmpty
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Successfully added ${_selectedPlaceIds.length} place(s) to itinerary!',
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add Selected to Itinerary (${_selectedPlaceIds.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}