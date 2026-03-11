import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
import 'package:finpredict/features/loans/screens/loan_detail_screen.dart';
import 'package:finpredict/features/loans/screens/add_loan_screen.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  _LoanListScreenState createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Pending, Partially Paid, Completed
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Loan Tracking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by borrower name...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Partially Paid'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLoanScreen()),
          );
        },
        backgroundColor: const Color(0xFFFBA002),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Loan',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('loans')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBA002)),
              );
            }

            final loans = snapshot.data!.docs;

            // Apply filters
            var filteredLoans = loans.where((doc) {
              final loan = doc.data() as Map<String, dynamic>;
              final borrower = (loan['borrower'] as String).toLowerCase();
              final status = loan['status'] as String;

              // Apply search filter
              if (_searchQuery.isNotEmpty && !borrower.contains(_searchQuery)) {
                return false;
              }

              // Apply status filter
              if (_selectedFilter != 'All') {
                final filterStatus =
                    _selectedFilter.toLowerCase().replaceAll(' ', '_');
                if (status != filterStatus) {
                  return false;
                }
              }

              return true;
            }).toList();

            if (filteredLoans.isEmpty) {
              return _buildEmptyState();
            }

            // Group loans by borrower
            final Map<String, List<DocumentSnapshot>> groupedLoans = {};
            for (var loan in filteredLoans) {
              final loanData = loan.data() as Map<String, dynamic>;
              final borrower = loanData['borrower'] as String;

              if (!groupedLoans.containsKey(borrower)) {
                groupedLoans[borrower] = [];
              }
              groupedLoans[borrower]!.add(loan);
            }

            return ListView.builder(
              itemCount: groupedLoans.length,
              itemBuilder: (context, index) {
                final borrower = groupedLoans.keys.elementAt(index);
                final borrowerLoans = groupedLoans[borrower]!;

                return _buildBorrowerSection(borrower, borrowerLoans);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      backgroundColor: const Color(0xFF1E293B),
      selectedColor: _getStatusColorForFilter(label),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? _getStatusColorForFilter(label)
              : const Color(0xFF334155),
        ),
      ),
    );
  }

  Color _getStatusColorForFilter(String filter) {
    switch (filter) {
      case 'Pending':
        return const Color(0xFFEF4444);
      case 'Partially Paid':
        return const Color(0xFFFBA002);
      case 'Completed':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Widget _buildBorrowerSection(String borrower, List<DocumentSnapshot> loans) {
    // Calculate totals for this borrower
    double totalLoaned = 0;
    double totalRepaid = 0;
    double totalRemaining = 0;
    int activeLoans = 0;

    for (var loanDoc in loans) {
      final loan = loanDoc.data() as Map<String, dynamic>;
      final remaining = (loan['remaining'] as num).toDouble();
      final repaid = (loan['totalRepaid'] as num).toDouble();
      final amount = (loan['amount'] as num).toDouble();

      totalLoaned += amount;
      totalRepaid += repaid;
      totalRemaining += remaining;

      if (loan['status'] != 'completed') {
        activeLoans++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrower,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeLoans active • ${loans.length} total loans',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Remaining',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Rs. ${totalRemaining.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...loans.map((loan) => _buildLoanCard(loan, borrower)).toList(),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF334155), height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLoanCard(DocumentSnapshot loanDoc, String borrower) {
    final loan = loanDoc.data() as Map<String, dynamic>;
    final loanDate = DateTime.parse(loan['date']);
    final remaining = (loan['remaining'] as num).toDouble();
    final totalRepaid = (loan['totalRepaid'] as num).toDouble();
    final totalAmount = (loan['amount'] as num).toDouble();
    final repaymentPercentage =
        totalAmount > 0 ? (totalRepaid / totalAmount) * 100 : 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoanDetailScreen(loanId: loanDoc.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          width: double.infinity,
          borderRadius: 16,
          blur: 8,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.attach_money,
                              color: Color(0xFFFBA002),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rs. ${totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loan['description'] ?? 'No description',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(loan['status']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _getStatusColor(loan['status'])),
                      ),
                      child: Text(
                        loan['status']
                            .toString()
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(loan['status']),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(loanDate),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${repaymentPercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: repaymentPercentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining: Rs. ${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: remaining > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (remaining > 0)
                      GestureDetector(
                        onTap: () {
                          _showAddAnotherLoanDialog(borrower);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBA002).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFBA002)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: Color(0xFFFBA002),
                                size: 14,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Add Another',
                                style: TextStyle(
                                  color: Color(0xFFFBA002),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAnotherLoanDialog(String borrowerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Add Another Loan',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Do you want to add another loan for $borrowerName?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLoanScreen(
                    initialBorrowerName: borrowerName,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBA002),
            ),
            child: const Text('Add Loan'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Color(0xFF94A3B8),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No loans found for "$_searchQuery"'
                : 'No loans recorded',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap + to add your first loan!',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Add New Loan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddLoanScreen(),
                ),
              );
            },
            width: 200,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'partially_paid':
        return const Color(0xFFFBA002);
      case 'pending':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
