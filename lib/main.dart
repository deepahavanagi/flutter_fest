import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================================
// 1. ABSTRACTION & INTERFACES
// ============================================================================

/// Abstraction: Abstract base class representing any event in the fest.
abstract class FestEvent {
  final String title;
  final String venue;

  FestEvent(this.title, this.venue);

  // Abstract methods enforcing sub-class implementation
  String getEventDetails();
  IconData getIcon();

  // Concrete getter
  String get locationInfo => 'Venue: $venue';
}

/// Interface: Contracts for events that issue certificates.
abstract class Certifiable {
  void generateCertificate(String studentName);
  bool get offersCertificate;
}

// ============================================================================
// DATA MODELS
// ============================================================================

/// Model: Represents a student registration for an event
class Registration {
  final String id;
  final String studentName;
  final String phoneNumber;
  final String college;
  final String emailAddress;
  final String eventTitle;
  final String eventVenue;
  final String eventType;
  final DateTime registeredAt;

  Registration({
    required this.id,
    required this.studentName,
    required this.phoneNumber,
    required this.college,
    required this.emailAddress,
    required this.eventTitle,
    required this.eventVenue,
    required this.eventType,
    required this.registeredAt,
  });

  factory Registration.fromJson(Map<String, dynamic> json) {
    return Registration(
      id: json['id'].toString(),
      studentName: json['student_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      college: json['college'] ?? '',
      emailAddress: json['email_address'] ?? '',
      eventTitle: json['event_title'] ?? '',
      eventVenue: json['event_venue'] ?? '',
      eventType: json['event_type'] ?? '',
      registeredAt: DateTime.parse(json['registered_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// ============================================================================
// PDF & VOUCHER GENERATION SERVICE
// ============================================================================

class VoucherTicketService {
  /// Fetch registrations for a specific event from Supabase
  static Future<List<Registration>> fetchEventRegistrations(
    String eventTitle,
  ) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception('Supabase credentials not configured');
    }

    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/registrations?event_title=eq.$eventTitle',
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch registrations');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Registration.fromJson(json)).toList();
  }

  /// Generate a PDF voucher ticket for a registration
  static Future<void> generateAndPrintVoucherPDF(Registration registration) async {
    final pdf = pw.Document();

    // Add the voucher ticket page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2, color: PdfColor.fromHex('#3AB7B1')),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'KLE Haveri BCA',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#3AB7B1'),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Event Voucher Ticket',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0E0D0D'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Divider
                pw.Container(
                  height: 2,
                  color: PdfColor.fromHex('#3AB7B1'),
                ),
                pw.SizedBox(height: 20),

                // Ticket Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Student Information',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        _buildDetailRow('Name:', registration.studentName),
                        _buildDetailRow('Email:', registration.emailAddress),
                        _buildDetailRow('Phone:', registration.phoneNumber),
                        _buildDetailRow('College:', registration.college),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Event Information',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        _buildDetailRow('Event:', registration.eventTitle),
                        _buildDetailRow('Venue:', registration.eventVenue),
                        _buildDetailRow(
                          'Date:',
                          DateFormat('dd/MM/yyyy').format(registration.registeredAt),
                        ),
                        _buildDetailRow(
                          'Time:',
                          DateFormat('HH:mm').format(registration.registeredAt),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Divider
                pw.Container(
                  height: 2,
                  color: PdfColor.fromHex('#3AB7B1'),
                ),
                pw.SizedBox(height: 20),

                // Footer with ticket ID
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Voucher Ticket ID: ${registration.id}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'This voucher is valid for the registered event only.',
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Print or save the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Helper method to build detail rows in PDF
  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Container(
            width: 180,
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. MIXINS (Reusable Feature Injection)
// ============================================================================

/// Mixin adding sponsorship and budget handling to events.
mixin SponsorshipRequirement {
  double _budget = 0.0; // Encapsulated private field

  double get budget => _budget;

  void addSponsorship(double amount) {
    if (amount > 0) {
      _budget += amount;
    }
  }

  void allocateExpense(double amount) {
    if (amount <= _budget) {
      _budget -= amount;
    }
  }
}

// ============================================================================
// 3. ENCAPSULATION, INHERITANCE & POLYMORPHISM
// ============================================================================

/// Subclass 1: [TechnicalEvent] extends [FestEvent], uses mixin & interface
class TechnicalEvent extends FestEvent
    with SponsorshipRequirement
    implements Certifiable {
  // Encapsulation: Private members
  int _registrationsCount = 0;
  final int _maxCapacity;

  // Static Member: Tracks total fest registrations across all technical events
  static int totalFestRegistrations = 0;

  // Standard Constructor with super-initializer
  TechnicalEvent(super.title, super.venue, this._maxCapacity);

  // Named Constructor
  TechnicalEvent.codingCompetition(String title)
    : _maxCapacity = 50,
      super(title, 'Lab 302');

  // Factory Constructor: Creates specialized preset events
  factory TechnicalEvent.hackathon() {
    return TechnicalEvent('Ai and Machine Learning', 'Main Auditorium', 100);
  }

  // Getters & Setters for Encapsulated Fields
  int get registrationsCount => _registrationsCount;
  bool get hasCapacity => _registrationsCount < _maxCapacity;

  bool registerStudent() {
    if (_registrationsCount < _maxCapacity) {
      _registrationsCount++;
      totalFestRegistrations++;
      return true;
    }
    return false;
  }

  // Polymorphic Implementation of Abstract Methods
  @override
  String getEventDetails() {
    return 'Tech Event | Slots: $_registrationsCount/$_maxCapacity';
  }

  @override
  IconData getIcon() => Icons.code;

  // Interface Implementation
  @override
  bool get offersCertificate => true;

  @override
  void generateCertificate(String studentName) {
    debugPrint('Certificate generated for $studentName in $title');
  }
}

/// Subclass 2: [CulturalEvent] demonstrating different Polymorphic behavior
class CulturalEvent extends FestEvent implements Certifiable {
  final String category; // e.g., Dance, Music, Drama
  bool _isStageReady = false;

  CulturalEvent(super.title, super.venue, this.category);

  void prepareStage() {
    _isStageReady = true;
  }

  // Polymorphic Overriding
  @override
  String getEventDetails() {
    final status = _isStageReady ? 'Stage Ready' : 'Rehearsals Ongoing';
    return 'Cultural ($category) | Status: $status';
  }

  @override
  IconData getIcon() => Icons.music_note;

  // Interface Implementation
  @override
  bool get offersCertificate => false; // Cultural events might just give trophies

  @override
  void generateCertificate(String studentName) {
    debugPrint('Participation award generated for $studentName');
  }
}

// ============================================================================
// 4. FLUTTER UI INTEGRATION
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(
    const MaterialApp(
      home: CollegeFestDashboard(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class CollegeFestDashboard extends StatefulWidget {
  const CollegeFestDashboard({super.key});

  @override
  State<CollegeFestDashboard> createState() => _CollegeFestDashboardState();
}

class _CollegeFestDashboardState extends State<CollegeFestDashboard> {
  // Polymorphic List holding base type reference [FestEvent]
  late final List<FestEvent> _festEvents;
  final List<String> _galleryImages = [
    'assets/fest_poster.jpeg',
    'assets/fest_poster1.jpeg',
    'assets/fest_poster2.jpeg',
  ];
  int _currentGalleryIndex = 0;
  Timer? _galleryTimer;

  @override
  void initState() {
    super.initState();
    // Instantiating concrete subclasses via various constructors
    _festEvents = [
      TechnicalEvent.hackathon(), // Factory Constructor
      TechnicalEvent.codingCompetition('Hacakathon'), // Named Constructor
      TechnicalEvent(
        'Flutter Workshop',
        'Class room 502',
        40,
      ), // Standard Constructor
      CulturalEvent(
        'Kannada Orchestor',
        'College Ground',
        'Music',
      ), // Subclass 2
    ];

    _galleryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _currentGalleryIndex = (_currentGalleryIndex + 1) % _galleryImages.length;
      });
    });
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    super.dispose();
  }

  static const List<String> _navItems = [
    'Home',
    'Events',
    'About',
    'Gallery',
    'Contact',
  ];

  int _selectedNavIndex = 0;

  Widget _buildSectionContent() {
    switch (_selectedNavIndex) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 900),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(animation);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      _galleryImages[_currentGalleryIndex],
                      key: ValueKey<String>(_galleryImages[_currentGalleryIndex]),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              _buildHomeSummaryRow(),
              const SizedBox(height: 8),
              _buildHomeActionSection(),
              const SizedBox(height: 8),
            ],
          ),
        );
      case 1:
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _festEvents.length,
                itemBuilder: (context, index) {
                  final event = _festEvents[index];
                  return _buildEventCard(event);
                },
              ),
            ),
          ],
        );
      case 2:
        return _buildStaticPage(
          title: 'About',
          content:
              'KLE Haveri BCA is a vibrant student-driven platform celebrating creativity, technology, and teamwork through our annual college fest. The festival brings together students, faculty, and guests for a series of engaging events, competitions, and performances.',
        );
      case 3:
        return _buildStaticPage(
          title: 'Gallery',
          content:
              'Explore the highlights from previous editions of the fest, including performances, workshops, creative displays, and unforgettable moments captured across the campus.',
          extraWidget: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            padding: const EdgeInsets.only(top: 16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildGalleryCard('assets/fest_poster.jpeg'),
              _buildGalleryCard('assets/fest_poster1.jpeg'),
              _buildGalleryCard('assets/fest_poster2.jpeg'),
            ],
          ),
        );
      case 4:
        return _buildStaticPage(
          title: 'Contact',
          content:
              'For event registrations, sponsorships, and general queries, contact the KLE Haveri BCA organizing team. Reach out to us to participate, collaborate, or support the fest experience.',
          extraWidget: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text('Email: fest@klehaveri.edu.in',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Phone: +91 98765 43210', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Venue: KLE Haveri BCA Campus', style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      default:
        return _buildStaticPage(title: 'Home', content: 'Home view');
    }
  }

  Widget _buildStaticPage({
    required String title,
    required String content,
    Widget? extraWidget,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (extraWidget != null) extraWidget,
        ],
      ),
    );
  }

  Widget _buildGalleryCard(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildHomeSummaryRow() {
    const locationUrl = 'https://maps.google.com/?q=KLE+Haveri+BCA+College';
    final totalParticipants = _festEvents.fold<int>(
      0,
      (sum, event) => sum + (event is TechnicalEvent ? event.registrationsCount : 0),
    );

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.08 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryItem(
              icon: Icons.calendar_today,
              label: 'Aug 15 2026',
              color: const Color.fromARGB(255, 58, 183, 177),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final uri = Uri.parse(locationUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: _buildSummaryItem(
                icon: Icons.location_on,
                label: 'KLE Haveri BCA College',
                color: const Color.fromARGB(255, 58, 183, 177),
              ),
            ),
            _buildSummaryItem(
              icon: Icons.people,
              label: '$totalParticipants Participants',
              color: const Color.fromARGB(255, 58, 183, 177),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeActionSection() {
    return Center(
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedNavIndex = 1;
              });
            },
            icon: const Icon(Icons.event_available),
            label: const Text('View Events'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 58, 183, 177),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'KLE INDEPENDENCE DAY\n2026\nDevelop the next generation of freedom—register now to compile our rich heritage and deploy a future of endless possibilities at KLE Haveri.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                height: 1.5,
                color: Color.fromARGB(255, 31, 31, 31),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KLE Haveri BCA'),
        backgroundColor: const Color.fromARGB(255, 58, 183, 177),
        foregroundColor: const Color.fromARGB(255, 14, 13, 13),
        actions: [
          for (int index = 0; index < _navItems.length; index++)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    _selectedNavIndex == index
                    ? Colors.white
                    : const Color.fromARGB(255, 14, 13, 13),
                backgroundColor:
                    _selectedNavIndex == index
                    ? const Color.fromARGB(255, 23, 112, 108)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _navItems[index],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _buildSectionContent(),
      bottomNavigationBar: const AppFooter(),
    );
  }

  // Renders UI polymorphically using base class contract [FestEvent]
  Widget _buildEventCard(FestEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _openEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 196, 232, 233),
                  child: Icon(
                    event.getIcon(),
                    color: const Color.fromARGB(255, 58, 148, 183),
                  ), // Polymorphic Icon
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${event.locationInfo}\n${event.getEventDetails()}',
                ), // Polymorphic String
                trailing:
                    (event is Certifiable &&
                        (event as Certifiable).offersCertificate)
                    ? const Chip(
                        label: Text(
                          'Certificate',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Color.fromARGB(255, 105, 211, 240),
                      )
                    : null,
              ),
              const Divider(),
              // Type-specific action triggers
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (event is TechnicalEvent) ...[
                    Text('Budget: Rs${event.budget.toInt()}'), // Mixin property
                    IconButton(
                      icon: const Icon(
                        Icons.attach_money,
                        color: Color.fromARGB(255, 87, 175, 76),
                      ),
                      onPressed: () {
                        setState(() {
                          event.addSponsorship(100.0); // Mixin method
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Register'),
                      onPressed: () {
                        _showRegistrationDialog(event);
                      },
                    ),
                  ],
                  if (event is CulturalEvent) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.mic, size: 16),
                      label: const Text('Lets start the program'),
                      onPressed: () {
                        setState(() {
                          event.prepareStage();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEventDetails(FestEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EventDetailPage(event: event)),
    );
  }

  Future<void> _showRegistrationDialog(TechnicalEvent event) async {
    if (!event.hasCapacity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration full for this event.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final collegeController = TextEditingController();
    final emailController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Register for Event'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Student Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter student name';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: collegeController,
                        decoration: const InputDecoration(labelText: 'College'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter college name';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter email address';
                          }
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                          });

                          final success = await _submitRegistration(
                            event: event,
                            studentName: nameController.text,
                            phoneNumber: phoneController.text,
                            collegeName: collegeController.text,
                            emailAddress: emailController.text,
                          );

                          if (!mounted) return;
                          setState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            final registered = event.registerStudent();
                            if (registered) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Registration successful'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Registration limit reached.'),
                                ),
                              );
                            }
                            Navigator.of(context).pop();
                            setState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to submit registration.'),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _submitRegistration({
    required TechnicalEvent event,
    required String studentName,
    required String phoneNumber,
    required String collegeName,
    required String emailAddress,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supabase credentials are not configured.'),
        ),
      );
      return false;
    }

    final uri = Uri.parse('$supabaseUrl/rest/v1/registrations');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'return=representation',
      },
      body: jsonEncode({
        'student_name': studentName.trim(),
        'phone_number': phoneNumber.trim(),
        'college': collegeName.trim(),
        'email_address': emailAddress.trim(),
        'event_title': event.title,
        'event_venue': event.venue,
        'event_type': event.runtimeType.toString(),
        'registered_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    return response.statusCode == 201;
  }
}

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 58, 183, 177),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Follow Us',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _openLink('https://www.instagram.com/'),
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            tooltip: 'Instagram',
          ),
          IconButton(
            onPressed: () => _openLink('https://www.facebook.com/'),
            icon: const Icon(Icons.facebook, color: Colors.white),
            tooltip: 'Facebook',
          ),
          IconButton(
            onPressed: () => _openLink('https://www.youtube.com/'),
            icon: const Icon(Icons.play_circle_fill, color: Colors.white),
            tooltip: 'YouTube',
          ),
          IconButton(
            onPressed: () => _openLink('https://www.klehaveri.edu.in/'),
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: 'College Website',
          ),
        ],
      ),
    );
  }
}

class EventDetailPage extends StatefulWidget {
  final FestEvent event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Future<List<Registration>> _registrationsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch registrations for the current event
    _registrationsFuture = VoucherTicketService.fetchEventRegistrations(
      widget.event.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        backgroundColor: const Color.fromARGB(255, 58, 183, 177),
        foregroundColor: const Color.fromARGB(255, 14, 13, 13),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.12 * 255).round()),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/fest_poster.jpeg',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.locationInfo,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.getEventDetails(),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (widget.event is TechnicalEvent) ...[
                    Text(
                      'Budget: Rs${(widget.event as TechnicalEvent).budget.toInt()}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.event is CulturalEvent) ...[
                    Text(
                      'Category: ${(widget.event as CulturalEvent).category}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Event Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This page shows details of the selected fest event with a preview image and a summary of what to expect. Use this screen to review the venue, status, and special notes before joining the event.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  // Voucher Ticket Section
                  if (widget.event is Certifiable &&
                      (widget.event as Certifiable).offersCertificate) ...[
                    const Text(
                      'Voucher Tickets',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Registration>>(
                      future: _registrationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'No registrations found for this event yet.',
                              style: TextStyle(fontSize: 14),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'No registrations found for this event yet.',
                              style: TextStyle(fontSize: 14),
                            ),
                          );
                        }

                        final registrations = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: registrations.length,
                          itemBuilder: (context, index) {
                            final registration = registrations[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            registration.studentName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            registration.emailAddress,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await VoucherTicketService
                                              .generateAndPrintVoucherPDF(
                                            registration,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Voucher ticket generated successfully!',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error generating voucher: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon:
                                          const Icon(Icons.card_giftcard, size: 16),
                                      label: const Text('Download Voucher'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color.fromARGB(255, 58, 183, 177),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}