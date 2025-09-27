// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/secondary_providers.dart';

class ContactScreeningScreen extends StatefulWidget {
  final Map<String, dynamic>? memberData;
  final String? householdId;
  final String? patientId;

  const ContactScreeningScreen({
    super.key,
    this.memberData,
    this.householdId,
    this.patientId,
  });

  @override
  State<ContactScreeningScreen> createState() => _ContactScreeningScreenState();
}

class _ContactScreeningScreenState extends State<ContactScreeningScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Member info
  Map<String, dynamic> _memberInfo = {};

  // Symptom screening
  final Map<String, bool> _symptoms = {
    'persistent_cough': false,
    'cough_with_blood': false,
    'weight_loss': false,
    'loss_of_appetite': false,
    'fever': false,
    'night_sweats': false,
    'fatigue': false,
    'chest_pain': false,
    'shortness_of_breath': false,
  };

  // Risk assessment
  final Map<String, bool> _riskFactors = {
    'close_contact': false,
    'prolonged_exposure': false,
    'shared_sleeping_space': false,
    'shared_meals': false,
    'immunocompromised': false,
    'diabetes': false,
    'hiv_positive': false,
    'smoking': false,
    'alcohol_use': false,
    'malnutrition': false,
  };

  // Clinical examination
  final Map<String, String> _clinicalFindings = {
    'weight': '',
    'height': '',
    'temperature': '',
    'blood_pressure': '',
    'pulse_rate': '',
    'respiratory_rate': '',
    'general_appearance': '',
    'lymph_nodes': '',
    'chest_examination': '',
    'additional_notes': '',
  };

  // Test recommendations
  final Map<String, bool> _recommendedTests = {
    'chest_xray': false,
    'sputum_smear': false,
    'sputum_culture': false,
    'tuberculin_skin_test': false,
    'igra_test': false,
    'hiv_test': false,
    'diabetes_screening': false,
  };

  // Referral fields
  String? _selectedFacilityId;
  String? _selectedFacilityName;
  String? _referralReason;
  String _referralUrgency = 'medium';
  List<Map<String, dynamic>> _nearbyFacilities = [];
  bool _isLoadingFacilities = false;

  String _overallRiskLevel = 'low';
  final List<String> _referralRecommendations = [];

  final List<Map<String, String>> _symptomDefinitions = [
    {
      'key': 'persistent_cough',
      'title': 'Persistent Cough',
      'description': 'Cough lasting more than 2-3 weeks',
    },
    {
      'key': 'cough_with_blood',
      'title': 'Cough with Blood',
      'description': 'Blood in sputum or coughing up blood',
    },
    {
      'key': 'weight_loss',
      'title': 'Weight Loss',
      'description': 'Significant weight loss without trying',
    },
    {
      'key': 'loss_of_appetite',
      'title': 'Loss of Appetite',
      'description': 'Reduced desire to eat',
    },
    {
      'key': 'fever',
      'title': 'Fever',
      'description': 'Body temperature above normal, especially at night',
    },
    {
      'key': 'night_sweats',
      'title': 'Night Sweats',
      'description': 'Excessive sweating during sleep',
    },
    {
      'key': 'fatigue',
      'title': 'Fatigue',
      'description': 'Unusual tiredness or weakness',
    },
    {
      'key': 'chest_pain',
      'title': 'Chest Pain',
      'description': 'Pain in chest area, especially when breathing',
    },
    {
      'key': 'shortness_of_breath',
      'title': 'Shortness of Breath',
      'description': 'Difficulty breathing or feeling breathless',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentStep = _tabController.index;
      });
    });

    _fadeController.forward();
    _loadMemberInfo();
    _loadNearbyFacilities();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadMemberInfo() {
    _memberInfo =
        widget.memberData ??
        {
          'id': 'HM001',
          'name': 'Fatima Khan',
          'age': 32,
          'gender': 'Female',
          'relationship': 'Spouse',
          'phone': '+92 300 7654321',
          'patientId': 'PAT001',
          'householdId': 'HH001',
        };
  }

  void _loadNearbyFacilities() async {
    setState(() {
      _isLoadingFacilities = true;
    });

    try {
      final contactProvider = Provider.of<ContactTracingProvider>(
        context,
        listen: false,
      );

      // Load real facilities from Firestore
      _nearbyFacilities = await contactProvider.getNearbyFacilities();
      print('Loaded ${_nearbyFacilities.length} facilities from Firestore');

      if (_nearbyFacilities.isEmpty) {
        print('No facilities found in Firestore');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No facilities available. Please add facilities to Firestore.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _isLoadingFacilities = false;
      });
    } catch (e) {
      print('Error loading facilities: $e');
      _nearbyFacilities = [];
      setState(() {
        _isLoadingFacilities = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load facilities: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactTracingProvider>(
      builder: (context, contactProvider, child) {
        return Scaffold(
          backgroundColor: MadadgarTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Contact Screening',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: MadadgarTheme.primaryColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
              tabs: const [
                Tab(text: 'Symptoms'),
                Tab(text: 'Risk Factors'),
                Tab(text: 'Examination'),
                Tab(text: 'Assessment'),
              ],
            ),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildMemberHeader(),
                  _buildProgressIndicator(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSymptomsTab(),
                        _buildRiskFactorsTab(),
                        _buildExaminationTab(),
                        _buildAssessmentTab(),
                      ],
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _memberInfo['gender'] == 'Male'
                ? Colors.blue.withOpacity(0.1)
                : Colors.pink.withOpacity(0.1),
            child: Icon(
              _memberInfo['gender'] == 'Male' ? Icons.man : Icons.woman,
              color: _memberInfo['gender'] == 'Male'
                  ? Colors.blue
                  : Colors.pink,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memberInfo['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${_memberInfo['age']} years • ${_memberInfo['relationship']} • ID: ${_memberInfo['id']}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'SCREENING',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(4, (index) {
          bool isCompleted = index < _currentStep;
          bool isCurrent = index == _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? MadadgarTheme.primaryColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSymptomsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sick, color: MadadgarTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Symptom Assessment',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check all symptoms that the contact person is currently experiencing:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          ..._symptomDefinitions.map((symptom) {
            return _buildSymptomCard(symptom);
          }).toList(),

          const SizedBox(height: 16),

          _buildSymptomSummary(),
        ],
      ),
    );
  }

  Widget _buildSymptomCard(Map<String, String> symptom) {
    bool isSelected = _symptoms[symptom['key']] ?? false;
    bool isHighPriority = [
      'cough_with_blood',
      'persistent_cough',
      'weight_loss',
    ].contains(symptom['key']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: () {
            setState(() {
              _symptoms[symptom['key']!] = !isSelected;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? (isHighPriority ? Colors.red : MadadgarTheme.primaryColor)
                    : Colors.transparent,
                width: 2,
              ),
              color: isSelected
                  ? (isHighPriority
                        ? Colors.red.withOpacity(0.1)
                        : MadadgarTheme.primaryColor.withOpacity(0.1))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isHighPriority
                                ? Colors.red
                                : MadadgarTheme.primaryColor)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected
                        ? (isHighPriority
                              ? Colors.red
                              : MadadgarTheme.primaryColor)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            symptom['title']!,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (isHighPriority) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'HIGH PRIORITY',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        symptom['description']!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomSummary() {
    int selectedCount = _symptoms.values.where((v) => v).length;
    bool hasHighPrioritySymptoms = _symptoms.entries
        .where(
          (e) => [
            'cough_with_blood',
            'persistent_cough',
            'weight_loss',
          ].contains(e.key),
        )
        .any((e) => e.value);

    Color summaryColor = hasHighPrioritySymptoms
        ? Colors.red
        : selectedCount > 0
        ? Colors.orange
        : Colors.green;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: summaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasHighPrioritySymptoms
                      ? Icons.warning
                      : selectedCount > 0
                      ? Icons.info
                      : Icons.check_circle,
                  color: summaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Symptom Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: summaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedCount == 0
                  ? 'No symptoms reported'
                  : '$selectedCount symptom${selectedCount > 1 ? 's' : ''} reported',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: summaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasHighPrioritySymptoms) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  '⚠️ High priority symptoms detected. Immediate medical evaluation recommended.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiskFactorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: MadadgarTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Risk Factor Assessment',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Identify risk factors that increase the likelihood of TB transmission:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildRiskFactorSection('Exposure Factors', [
            {
              'key': 'close_contact',
              'title': 'Close Contact',
              'description': 'Regular close contact with TB patient',
            },
            {
              'key': 'prolonged_exposure',
              'title': 'Prolonged Exposure',
              'description': 'Extended time spent with TB patient',
            },
            {
              'key': 'shared_sleeping_space',
              'title': 'Shared Sleeping Space',
              'description': 'Sleeping in same room/bed',
            },
            {
              'key': 'shared_meals',
              'title': 'Shared Meals',
              'description': 'Eating meals together regularly',
            },
          ]),

          const SizedBox(height: 16),

          _buildRiskFactorSection('Medical Risk Factors', [
            {
              'key': 'immunocompromised',
              'title': 'Immunocompromised',
              'description': 'Weakened immune system',
            },
            {
              'key': 'diabetes',
              'title': 'Diabetes',
              'description': 'Diagnosed with diabetes mellitus',
            },
            {
              'key': 'hiv_positive',
              'title': 'HIV Positive',
              'description': 'HIV infection',
            },
            {
              'key': 'malnutrition',
              'title': 'Malnutrition',
              'description': 'Poor nutritional status',
            },
          ]),

          const SizedBox(height: 16),

          _buildRiskFactorSection('Lifestyle Risk Factors', [
            {
              'key': 'smoking',
              'title': 'Smoking',
              'description': 'Current or recent tobacco use',
            },
            {
              'key': 'alcohol_use',
              'title': 'Alcohol Use',
              'description': 'Regular alcohol consumption',
            },
          ]),

          const SizedBox(height: 16),

          _buildRiskSummary(),
        ],
      ),
    );
  }

  Widget _buildRiskFactorSection(
    String title,
    List<Map<String, String>> factors,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...factors.map((factor) => _buildRiskFactorTile(factor)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskFactorTile(Map<String, String> factor) {
    bool isSelected = _riskFactors[factor['key']] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _riskFactors[factor['key']!] = !isSelected;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? MadadgarTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? MadadgarTheme.primaryColor
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? MadadgarTheme.primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? MadadgarTheme.primaryColor
                        : Colors.grey.shade400,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor['title']!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      factor['description']!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskSummary() {
    int riskCount = _riskFactors.values.where((v) => v).length;
    String riskLevel;
    Color riskColor;

    if (riskCount >= 4) {
      riskLevel = 'HIGH';
      riskColor = Colors.red;
    } else if (riskCount >= 2) {
      riskLevel = 'MEDIUM';
      riskColor = Colors.orange;
    } else {
      riskLevel = 'LOW';
      riskColor = Colors.green;
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: riskColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: riskColor),
                const SizedBox(width: 8),
                Text(
                  'Risk Assessment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Risk Level: $riskLevel',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: riskColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$riskCount risk factor${riskCount != 1 ? 's' : ''} identified',
              style: GoogleFonts.poppins(fontSize: 14, color: riskColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExaminationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: MadadgarTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clinical Examination',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record clinical findings and vital signs:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vital Signs',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExaminationField(
                          'Weight (kg)',
                          'weight',
                          'e.g., 65',
                          TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildExaminationField(
                          'Height (cm)',
                          'height',
                          'e.g., 170',
                          TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExaminationField(
                          'Temperature (°C)',
                          'temperature',
                          'e.g., 37.2',
                          TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildExaminationField(
                          'Blood Pressure',
                          'blood_pressure',
                          'e.g., 120/80',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExaminationField(
                          'Pulse Rate (bpm)',
                          'pulse_rate',
                          'e.g., 72',
                          TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildExaminationField(
                          'Respiratory Rate',
                          'respiratory_rate',
                          'e.g., 16',
                          TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physical Examination',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildExaminationField(
                    'General Appearance',
                    'general_appearance',
                    'Overall condition and appearance',
                    null,
                    2,
                  ),
                  const SizedBox(height: 16),
                  _buildExaminationField(
                    'Lymph Nodes',
                    'lymph_nodes',
                    'Lymph node examination findings',
                    null,
                    2,
                  ),
                  const SizedBox(height: 16),
                  _buildExaminationField(
                    'Chest Examination',
                    'chest_examination',
                    'Respiratory examination findings',
                    null,
                    3,
                  ),
                  const SizedBox(height: 16),
                  _buildExaminationField(
                    'Additional Notes',
                    'additional_notes',
                    'Any other clinical findings',
                    null,
                    3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExaminationField(
    String label,
    String key,
    String hint, [
    TextInputType? keyboardType,
    int maxLines = 1,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _clinicalFindings[key],
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MadadgarTheme.primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            _clinicalFindings[key] = value;
          },
        ),
      ],
    );
  }

  Widget _buildAssessmentTab() {
    _calculateOverallAssessment();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment, color: MadadgarTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Screening Assessment',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on symptoms, risk factors, and examination findings:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildOverallRiskCard(),

          const SizedBox(height: 16),

          _buildRecommendedTestsCard(),

          const SizedBox(height: 16),

          _buildReferralRecommendationsCard(),

          const SizedBox(height: 16),

          // Always show facility selection for testing
          _buildFacilitySelectionCard(),

          const SizedBox(height: 16),

          _buildScreeningSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildOverallRiskCard() {
    Color riskColor = _getRiskColor(_overallRiskLevel);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: riskColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: riskColor),
                const SizedBox(width: 8),
                Text(
                  'Overall Risk Assessment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: riskColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_overallRiskLevel.toUpperCase()} RISK',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getRecommendedAction(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: riskColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedTestsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Recommended Tests',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._getRecommendedTestsList()
                .map((test) => _buildTestCheckbox(test))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCheckbox(Map<String, String> test) {
    bool isRecommended = _recommendedTests[test['key']] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: isRecommended,
            onChanged: (value) {
              setState(() {
                _recommendedTests[test['key']!] = value ?? false;
              });
            },
            activeColor: MadadgarTheme.primaryColor,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test['title']!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  test['description']!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralRecommendationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_hospital, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Referral Recommendations',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._referralRecommendations.map((referral) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        referral,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (_referralRecommendations.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'No immediate referral needed',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitySelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Select Referral Facility',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose the nearest facility for referral:',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            ),
            Text(
              '${_nearbyFacilities.length} facilities available nearby',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white, // or MadadgarTheme.secondaryColor
                fontWeight: FontWeight.w500,
              ),
            ),

            ElevatedButton(
              onPressed: () {
                _loadNearbyFacilities();
              },
              child: Text('Refresh Facilities'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedFacilityId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isLoadingFacilities
                    ? 'Loading facilities...'
                    : 'Select Facility',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: _isLoadingFacilities
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),

              items: _isLoadingFacilities
                  ? [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'Loading facilities...',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ]
                  : _nearbyFacilities.map((facility) {
                      // Create a single line description
                      String facilityDescription = facility['name'];
                      if (facility['distance'] > 0) {
                        facilityDescription +=
                            ' (${facility['distance'].toStringAsFixed(1)} km)';
                      }

                      return DropdownMenuItem<String>(
                        value: facility['facilityId'],
                        child: Text(
                          facilityDescription,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFacilityId = value;
                  if (value != null) {
                    final facility = _nearbyFacilities.firstWhere(
                      (f) => f['facilityId'] == value,
                    );
                    _selectedFacilityName = facility['name'];
                  }
                });
              },
            ),
            if (_selectedFacilityId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Referral Details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _referralUrgency,
                decoration: InputDecoration(
                  labelText: 'Urgency Level',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text('Low Priority', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(
                      'Medium Priority',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text('High Priority', style: GoogleFonts.poppins()),
                  ),
                  DropdownMenuItem(
                    value: 'urgent',
                    child: Text('Urgent', style: GoogleFonts.poppins()),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _referralUrgency = value ?? 'medium';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _referralReason,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Referral Reason',
                  hintText: 'Specify why this referral is needed...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _referralReason = value;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScreeningSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Screening Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Symptoms',
              '${_symptoms.values.where((v) => v).length}/9 reported',
            ),
            _buildSummaryRow(
              'Risk Factors',
              '${_riskFactors.values.where((v) => v).length}/10 identified',
            ),
            _buildSummaryRow(
              'Tests Recommended',
              '${_recommendedTests.values.where((v) => v).length} tests',
            ),
            _buildSummaryRow('Overall Risk', _overallRiskLevel.toUpperCase()),
            _buildSummaryRow(
              'Screening Date',
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _tabController.animateTo(_currentStep - 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),

          if (_currentStep > 0) const SizedBox(width: 16),

          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < 3
                  ? () => _tabController.animateTo(_currentStep + 1)
                  : _submitScreening,
              style: ElevatedButton.styleFrom(
                backgroundColor: MadadgarTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Submitting...',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _currentStep < 3 ? 'Next' : 'Complete Screening',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _calculateOverallAssessment() {
    int riskScore = 0;

    // Symptom scoring
    int symptomCount = _symptoms.values.where((v) => v).length;
    bool hasHighPrioritySymptoms = _symptoms.entries
        .where(
          (e) => [
            'cough_with_blood',
            'persistent_cough',
            'weight_loss',
          ].contains(e.key),
        )
        .any((e) => e.value);

    if (hasHighPrioritySymptoms) {
      riskScore += 5;
    } else if (symptomCount >= 3)
      riskScore += 3;
    else if (symptomCount >= 1)
      riskScore += 1;

    // Risk factor scoring
    int riskFactorCount = _riskFactors.values.where((v) => v).length;
    if (riskFactorCount >= 4)
      riskScore += 4;
    else if (riskFactorCount >= 2)
      riskScore += 2;
    else if (riskFactorCount >= 1)
      riskScore += 1;

    // Determine overall risk level
    if (riskScore >= 6) {
      _overallRiskLevel = 'high';
    } else if (riskScore >= 3) {
      _overallRiskLevel = 'medium';
    } else {
      _overallRiskLevel = 'low';
    }

    // Set referral recommendations
    _referralRecommendations.clear();
    if (_overallRiskLevel == 'high') {
      _referralRecommendations.addAll([
        'Immediate referral to TB specialist',
        'Urgent chest X-ray and sputum examination',
        'Start daily monitoring',
      ]);
    } else if (_overallRiskLevel == 'medium') {
      _referralRecommendations.addAll([
        'Referral to health facility for further evaluation',
        'Schedule follow-up in 2 weeks',
      ]);
    }

    // Add nearest facility recommendation for medium/high risk
    if (_overallRiskLevel != 'low') {
      _referralRecommendations.add(_facilityReferralText());
    }

    if (hasHighPrioritySymptoms) {
      _referralRecommendations.add('Emergency evaluation for TB symptoms');
    }
  }

  List<Map<String, String>> _getRecommendedTestsList() {
    List<Map<String, String>> tests = [];

    // Always recommend basic tests
    tests.add({
      'key': 'chest_xray',
      'title': 'Chest X-ray',
      'description': 'To check for lung abnormalities',
    });

    // Symptom-based recommendations
    if (_symptoms['persistent_cough'] == true ||
        _symptoms['cough_with_blood'] == true) {
      tests.addAll([
        {
          'key': 'sputum_smear',
          'title': 'Sputum Smear Microscopy',
          'description': 'To detect TB bacteria in sputum',
        },
        {
          'key': 'sputum_culture',
          'title': 'Sputum Culture',
          'description': 'More sensitive test for TB bacteria',
        },
      ]);
    }

    // Risk-based recommendations
    if (_riskFactors['hiv_positive'] != true && _overallRiskLevel != 'low') {
      tests.add({
        'key': 'hiv_test',
        'title': 'HIV Test',
        'description': 'HIV increases TB risk',
      });
    }

    if (_riskFactors['diabetes'] != true) {
      tests.add({
        'key': 'diabetes_screening',
        'title': 'Diabetes Screening',
        'description': 'Diabetes increases TB risk',
      });
    }

    tests.add({
      'key': 'tuberculin_skin_test',
      'title': 'Tuberculin Skin Test (TST)',
      'description': 'To detect latent TB infection',
    });

    // Auto-select based on risk level
    if (_overallRiskLevel == 'high') {
      _recommendedTests['chest_xray'] = true;
      _recommendedTests['sputum_smear'] = true;
      _recommendedTests['tuberculin_skin_test'] = true;
    } else if (_overallRiskLevel == 'medium') {
      _recommendedTests['chest_xray'] = true;
      _recommendedTests['tuberculin_skin_test'] = true;
    }

    return tests;
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRecommendedAction() {
    switch (_overallRiskLevel) {
      case 'high':
        return 'Immediate medical evaluation and testing required';
      case 'medium':
        return 'Schedule evaluation within 1 week';
      case 'low':
        return 'Continue routine monitoring and health education';
      default:
        return 'Follow standard screening protocol';
    }
  }

  // Basic placeholder facility suggestion based on risk level
  // In future, replace with GPS + real facility list (Firestore/API)
  Map<String, String> _getFacilityRecommendation() {
    switch (_overallRiskLevel) {
      case 'high':
        return {
          'name': 'District TB Hospital',
          'distance': '5.0 km',
          'contact': '+92 51 1234567',
        };
      case 'medium':
        return {
          'name': 'Community Health Center',
          'distance': '2.5 km',
          'contact': '+92 51 7654321',
        };
      default:
        return {
          'name': 'Primary Care Clinic',
          'distance': '1.2 km',
          'contact': '+92 51 1112223',
        };
    }
  }

  String _facilityReferralText() {
    final facility = _getFacilityRecommendation();
    return 'Refer to ${facility['name']} (${facility['distance']}) for evaluation and testing.';
  }

  void _submitScreening() async {
    setState(() => _isSubmitting = true);

    try {
      // Get the provider
      final contactProvider = Provider.of<ContactTracingProvider>(
        context,
        listen: false,
      );

      // Prepare screening data
      List<String> symptoms = _symptoms.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      List<String> riskFactors = _riskFactors.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Determine placeholder nearest facility based on risk
      final facility = _getFacilityRecommendation();
      final notes =
          'Contact screening completed via CHW mobile app. Risk level: $_overallRiskLevel. Risk factors: ${riskFactors.join(', ')}. Referral: ${facility['name']} (${facility['distance']}), Contact: ${facility['contact']}.';

      // Submit the screening
      await contactProvider.screenContact(
        householdId: widget.householdId ?? 'unknown',
        indexPatientId: widget.patientId ?? 'unknown',
        contactName: _memberInfo['name'] ?? 'Unknown',
        relationship: _memberInfo['relationship'] ?? 'Unknown',
        age: _memberInfo['age'] ?? 0,
        gender: _memberInfo['gender'] ?? 'Unknown',
        symptoms: symptoms,
        notes: notes,
        referredFacilityId: _selectedFacilityId,
        referredFacilityName: _selectedFacilityName,
        referralReason: _referralReason,
        referralUrgency: _referralUrgency,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save screening: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show success message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Screening Done', style: GoogleFonts.poppins()),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact screening for ${_memberInfo['name']} has been completed successfully.',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRiskColor(_overallRiskLevel).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Level: ${_overallRiskLevel.toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: _getRiskColor(_overallRiskLevel),
                    ),
                  ),
                  Text(
                    _getRecommendedAction(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _getRiskColor(_overallRiskLevel),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedFacilityId != null
                              ? 'Referred to: $_selectedFacilityName (${_referralUrgency.toUpperCase()} priority)'
                              : _facilityReferralText(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_overallRiskLevel == 'high')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _scheduleUrgentFollowUp();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Schedule Urgent Follow-up',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Return to Household', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _scheduleUrgentFollowUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Urgent follow-up scheduled for tomorrow',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pop(context);
  }
}
