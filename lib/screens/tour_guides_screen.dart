import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. UPDATED STATIC ORGANIZATION DATA
const Map<String, Map<String, dynamic>> _orgData = {
  'EGAY': {
    'fullName': 'EGAY',
    'contact': '0970 136 1939',
    'president': null,
    'trainings': [
      'Basic Life Support',
      'History and Culture',
      'Cave and Rescue',
      'Customer Service'
    ],
    'accreditation': 'LGU / DOT',
    'year': null, // No year data
  },
  'SAGGAS': {
    'fullName': 'Sagada Genuine Guides Association',
    'contact': '0949 943 1686',
    'president': 'Esperanza Page-et',
    'trainings': [
      'Basic Life Support',
      'History and Culture',
      'Cave and Rescue',
      'Customer Service'
    ],
    'accreditation': 'LGU / DOT',
    'year': null,
  },
  'SEGA': {
    'fullName': 'Sagada Environmental Guides Association',
    'contact': '0997 736 6418',
    'president': 'Jed Angway',
    'trainings': [
      'Basic Life Support',
      'Customer Service Training',
      'Basic Water Rescue',
      'Waste Management Training'
    ],
    'accreditation': 'LGU / DOT',
    'year': null,
  },
  'BFTAMPGA': {
    'fullName':
        'Bangaan, Fidelisan, Tanulong, Aguid Madongo, Pide Guide Association',
    'desc': 'Exclusively for Bomod-ok Falls Only', // ⭐️ Kept Note here
    'contact': '0935 353 8169',
    'president': 'Salvador P. Labiang',
    'trainings': [
      'Tour Guiding Technique',
      'Basic Life Support',
      'Water Search and Rescue',
      'Mountain Search and Rescue',
      'Customer Service'
    ],
    'accreditation': 'LGU / DOT',
    'year': 2013, // ⭐️ Added Year
  },
  'SETGO': {
    'fullName': 'Sagada Ethnos Guides Organization',
    'contact': '0919 222 8182',
    'president': 'Johnny Nasgatan',
    // desc removed (Moved to Years in Service)
    'trainings': [
      'Basic Life Support',
      'History and Culture',
      'Cave and Rescue',
      'Customer Service'
    ],
    'accreditation': 'LGU / DOT',
    'year': 2014, // ⭐️ Added Year
  },
  'ASSET G': {
    'fullName': 'Association of Southern Sagada Environmental Tour Guides',
    'contact': '0962 535 5882',
    'president': 'Joey Taltala',
    // desc removed
    'trainings': [
      'Basic Life Support',
      'History and Culture',
      'Cave and Rescue',
      'Customer Service'
    ],
    'accreditation': 'LGU / DOT', // ⭐️ Updated to include LGU
    'year': 2014, // ⭐️ Added Year
  },
};

// 2. Data Model
class TourGuide {
  final String name;
  final String org;
  final String phone;
  final String imageUrl;
  final List<String> areas;

  TourGuide({
    required this.name,
    required this.org,
    required this.phone,
    required this.imageUrl,
    required this.areas,
  });

  factory TourGuide.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TourGuide(
      name: data['name'] ?? 'No Name',
      org: data['org'] ?? 'No Organization',
      phone: data['phone'] ?? '',
      imageUrl: data['image'] ?? '',
      areas: List<String>.from(
        data['area'] is List ? data['area'] : [data['area']],
      ),
    );
  }
}

class TourGuidesScreen extends StatefulWidget {
  const TourGuidesScreen({super.key});

  @override
  State<TourGuidesScreen> createState() => _TourGuidesScreenState();
}

class _TourGuidesScreenState extends State<TourGuidesScreen> {
  List<TourGuide> _allGuides = [];
  List<TourGuide> _displayedGuides = [];
  List<String> _organizations = ['All'];
  String _selectedOrg = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPrepareGuides();
    _searchController.addListener(_updateDisplayedGuides);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPrepareGuides() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('tourGuides').get();

      final guides = querySnapshot.docs
          .map((doc) => TourGuide.fromFirestore(doc))
          .toList();

      guides.shuffle();

      final orgs = guides.map((guide) => guide.org).toSet().toList();
      orgs.sort();

      setState(() {
        _allGuides = guides;
        _displayedGuides = guides;
        _organizations = ['All', ...orgs];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching tour guides: $e')));
    }
  }

  void _updateDisplayedGuides() {
    List<TourGuide> filteredGuides = List.from(_allGuides);

    if (_selectedOrg != 'All') {
      filteredGuides =
          filteredGuides.where((guide) => guide.org == _selectedOrg).toList();
    }

    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredGuides = filteredGuides.where((guide) {
        return guide.name.toLowerCase().contains(searchQuery);
      }).toList();
    }

    setState(() {
      _displayedGuides = filteredGuides;
    });
  }

  Widget _buildOrgHeaderInfo() {
    // A. Friendly Text for "All"
    if (_selectedOrg == 'All') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3A6A55).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A6A55).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: const Color(0xFF3A6A55), size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Select an organization above to view their headquarters details, trainings, and official contact numbers.",
                style: TextStyle(
                  color: Color(0xFF3A6A55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // B. Org Details
    final details = _orgData[_selectedOrg];
    if (details == null) return const SizedBox.shrink();

    // Calculate years in service
    String? yearsInService;
    if (details['year'] != null) {
      final int startYear = details['year'];
      final int currentYear = DateTime.now().year;
      final int diff = currentYear - startYear;
      if (diff > 0) {
        yearsInService = "$diff Years in Service";
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        // ⭐️ FIX: Removes the top/bottom borders when expanded
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF3A6A55),
            child: Text(
              _selectedOrg[0],
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            details['fullName'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            details['accreditation'] ?? 'Accredited Organization',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(), // Custom subtle divider
                  const SizedBox(height: 8),

                  // 1. Note (Only for BFTAMPGA)
                  if (details['desc'] != null) ...[
                    _buildInfoRow(Icons.star, "Note", details['desc']),
                    const SizedBox(height: 8),
                  ],

                  // 2. Years in Service (Computed)
                  if (yearsInService != null) ...[
                    _buildInfoRow(
                        Icons.history_edu, "Experience", yearsInService),
                    const SizedBox(height: 8),
                  ],

                  // 3. President
                  if (details['president'] != null) ...[
                    _buildInfoRow(
                        Icons.person, "President", details['president']),
                    const SizedBox(height: 8),
                  ],

                  // 4. Contact
                  _buildInfoRow(Icons.phone, "Contact", details['contact'],
                      isLink: true),
                  const SizedBox(height: 12),

                  // 5. Trainings
                  const Text(
                    "Trainings & Skills:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (details['trainings'] as List<String>).map((t) {
                      return Chip(
                        label: Text(t, style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isLink = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text("$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(
          child: isLink
              ? InkWell(
                  onTap: () {
                    final Uri url = Uri(scheme: 'tel', path: value);
                    launchUrl(url);
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                )
              : Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  void _showGuideDetailsDialog(BuildContext context, TourGuide guide) {
    Future<void> launchUrlHelper(Uri url) async {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(0),
          elevation: 10,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Header
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    image: DecorationImage(
                      image: guide.imageUrl.isNotEmpty
                          ? NetworkImage(guide.imageUrl) as ImageProvider
                          : const AssetImage('assets/placeholder_person.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4), BlendMode.darken),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6)
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          guide.org,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (guide.areas.isNotEmpty &&
                          guide.areas.first.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.map_outlined,
                              color: Color(0xFF3A6A55)),
                          // ⭐️ Updated Label
                          title: const Text('Areas of Specialization',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(guide.areas.join(", ")),
                        ),
                      if (guide.phone.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.phone_outlined,
                              color: Colors.blueAccent),
                          title: const Text('Phone',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(guide.phone),
                          onTap: () {
                            final Uri phoneUri =
                                Uri(scheme: 'tel', path: guide.phone);
                            launchUrlHelper(phoneUri);
                          },
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (guide.phone.isNotEmpty)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.phone),
                                label: const Text('Call Guide'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3A6A55),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  final Uri phoneUri =
                                      Uri(scheme: 'tel', path: guide.phone);
                                  launchUrlHelper(phoneUri);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220.0,
                  backgroundColor: const Color(0xFF3A6A55),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: const Text(
                      'Tour Guides',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/tourguide_background.png',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for a guide...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      itemCount: _organizations.length,
                      itemBuilder: (context, index) {
                        final org = _organizations[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(org),
                            selected: _selectedOrg == org,
                            onSelected: (isSelected) {
                              if (isSelected) {
                                setState(() {
                                  _selectedOrg = org;
                                  if (org == 'All') {
                                    _allGuides.shuffle();
                                  }
                                });
                                _updateDisplayedGuides();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildOrgHeaderInfo(),
                ),
                _displayedGuides.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No tour guides found for your search.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return TourGuideCard(
                              guide: _displayedGuides[index],
                              onTap: () => _showGuideDetailsDialog(
                                context,
                                _displayedGuides[index],
                              ),
                            );
                          }, childCount: _displayedGuides.length),
                        ),
                      ),
              ],
            ),
    );
  }
}

class TourGuideCard extends StatelessWidget {
  final TourGuide guide;
  final VoidCallback onTap;

  const TourGuideCard({super.key, required this.guide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            if (guide.imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  guide.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person,
                        size: 60, color: Colors.grey);
                  },
                ),
              )
            else
              Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
              ),
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    guide.org,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
