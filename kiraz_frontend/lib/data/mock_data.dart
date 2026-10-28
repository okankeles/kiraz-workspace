import '../models/financial_transaction.dart';
import '../models/mock_rent_period.dart';
import '../models/user_role.dart';

class MockData {
  static const List<UserRole> userRoles = [
    UserRole(
      id: 'role_1',
      userName: 'Erkan B.',
      propertyName: 'Tüm Mülkler (Ev Sahibi)',
      roleType: RoleType.landlord,
    ),
    UserRole(
      id: 'role_2',
      userName: 'Okan K.',
      propertyName: 'Kadıköy Daire (D:2)',
      roleType: RoleType.tenant,
    ),
    UserRole(
      id: 'role_3',
      userName: 'Murat Bey',
      propertyName: 'Sistem Yönetimi',
      roleType: RoleType.admin,
    ),
  ];

  static List<RentPeriod> rentPeriods = [
    // Şişli Daire (D:4) - Aylık Periyot
    RentPeriod(
      id: 'rent_1',
      propertyName: 'Şişli Daire (D:4)',
      monthName: 'Ağustos 2026',
      amount: 18000.0,
      status: PaymentStatus.paid,
    ),
    RentPeriod(
      id: 'rent_2',
      propertyName: 'Şişli Daire (D:4)',
      monthName: 'Eylül 2026',
      amount: 18000.0,
      status: PaymentStatus.paid,
    ),
    RentPeriod(
      id: 'rent_3',
      propertyName: 'Şişli Daire (D:4)',
      monthName: 'Ekim 2026',
      amount: 18000.0,
      status: PaymentStatus.unpaid,
    ),
    RentPeriod(
      id: 'rent_4',
      propertyName: 'Şişli Daire (D:4)',
      monthName: 'Kasım 2026',
      amount: 18000.0,
      status: PaymentStatus.unpaid,
    ),

    // Şişli Daire (D:7) - 3 Aylık (Çeyreklik) Periyot
    RentPeriod(
      id: 'rent_sisli7_1',
      propertyName: 'Şişli Daire (D:7)',
      monthName: 'Haziran - Ağustos 2026 (3 Aylık)',
      amount: 60000.0,
      status: PaymentStatus.paid,
    ),
    RentPeriod(
      id: 'rent_sisli7_2',
      propertyName: 'Şişli Daire (D:7)',
      monthName: 'Eylül - Kasım 2026 (3 Aylık)',
      amount: 60000.0,
      status: PaymentStatus.unpaid,
    ),

    // Kadıköy Daire (D:2) - Aylık Periyot
    RentPeriod(
      id: 'rent_5',
      propertyName: 'Kadıköy Daire (D:2)',
      monthName: 'Ağustos 2026',
      amount: 15000.0,
      status: PaymentStatus.paid,
    ),
    RentPeriod(
      id: 'rent_6',
      propertyName: 'Kadıköy Daire (D:2)',
      monthName: 'Eylül 2026',
      amount: 15000.0,
      status: PaymentStatus.pending,
    ),
    RentPeriod(
      id: 'rent_7',
      propertyName: 'Kadıköy Daire (D:2)',
      monthName: 'Ekim 2026',
      amount: 15000.0,
      status: PaymentStatus.unpaid,
    ),
  ];

  static List<FinancialTransaction> transactions = [
    FinancialTransaction(
      id: 'tx_seed_1',
      amount: 15000.0,
      date: DateTime.now().subtract(const Duration(days: 1)),
      propertyName: 'Kadıköy Daire (D:2)',
      status: TxStatus.pending,
      hasReceiptImage: true,
      rentPeriodId: 'rent_6',
    ),
  ];

  static double totalIncome = 96000.0;
  static double pendingCollection = 15000.0;

  /// Restores all mutable demo state to its initial values.
  static void reset() {
    rentPeriods = [
      RentPeriod(
        id: 'rent_1',
        propertyName: 'Şişli Daire (D:4)',
        monthName: 'Ağustos 2026',
        amount: 18000.0,
        status: PaymentStatus.paid,
      ),
      RentPeriod(
        id: 'rent_2',
        propertyName: 'Şişli Daire (D:4)',
        monthName: 'Eylül 2026',
        amount: 18000.0,
        status: PaymentStatus.paid,
      ),
      RentPeriod(
        id: 'rent_3',
        propertyName: 'Şişli Daire (D:4)',
        monthName: 'Ekim 2026',
        amount: 18000.0,
        status: PaymentStatus.unpaid,
      ),
      RentPeriod(
        id: 'rent_4',
        propertyName: 'Şişli Daire (D:4)',
        monthName: 'Kasım 2026',
        amount: 18000.0,
        status: PaymentStatus.unpaid,
      ),
      RentPeriod(
        id: 'rent_sisli7_1',
        propertyName: 'Şişli Daire (D:7)',
        monthName: 'Haziran - Ağustos 2026 (3 Aylık)',
        amount: 60000.0,
        status: PaymentStatus.paid,
      ),
      RentPeriod(
        id: 'rent_sisli7_2',
        propertyName: 'Şişli Daire (D:7)',
        monthName: 'Eylül - Kasım 2026 (3 Aylık)',
        amount: 60000.0,
        status: PaymentStatus.unpaid,
      ),
      RentPeriod(
        id: 'rent_5',
        propertyName: 'Kadıköy Daire (D:2)',
        monthName: 'Ağustos 2026',
        amount: 15000.0,
        status: PaymentStatus.paid,
      ),
      RentPeriod(
        id: 'rent_6',
        propertyName: 'Kadıköy Daire (D:2)',
        monthName: 'Eylül 2026',
        amount: 15000.0,
        status: PaymentStatus.pending,
      ),
      RentPeriod(
        id: 'rent_7',
        propertyName: 'Kadıköy Daire (D:2)',
        monthName: 'Ekim 2026',
        amount: 15000.0,
        status: PaymentStatus.unpaid,
      ),
    ];
    transactions = [
      FinancialTransaction(
        id: 'tx_seed_1',
        amount: 15000.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        propertyName: 'Kadıköy Daire (D:2)',
        status: TxStatus.pending,
        hasReceiptImage: true,
        rentPeriodId: 'rent_6',
      ),
    ];
    totalIncome = 96000;
    pendingCollection = 15000;
    properties = [
      {
        'name': 'Şişli Daire (D:4)',
        'building': 'Güneş Apartmanı',
        'unit': 'Kat 2, Daire 4',
        'address': 'Halaskargazi Cad. No:112 D:4, Şişli / İstanbul',
        'tenant': 'Ali V.',
        'tenantPhone': '0532 111 22 33',
        'landlord': 'Erkan B.',
        'paymentCycle': 'Aylık',
        'rentAmount': 18000.0,
        'deposit': '36.000 TL',
        'status': 'Ödeme Bekliyor',
        'daskExpiry': '15 gün kaldı',
      },
      {
        'name': 'Şişli Daire (D:7)',
        'building': 'Güneş Apartmanı',
        'unit': 'Kat 4, Daire 7 (Ön Cephe)',
        'address': 'Halaskargazi Cad. No:112 D:7, Şişli / İstanbul',
        'tenant': 'Mehmet S.',
        'tenantPhone': '0533 444 55 66',
        'landlord': 'Erkan B.',
        'paymentCycle': '3 Aylık (Çeyreklik)',
        'rentAmount': 60000.0,
        'deposit': '60.000 TL',
        'status': 'Ödeme Bekliyor',
        'daskExpiry': '180 gün var',
      },
      {
        'name': 'Kadıköy Daire (D:2)',
        'building': 'Moda Palas',
        'unit': 'Giriş Kat, Daire 2',
        'address': 'Moda Cad. No:45 D:2, Kadıköy / İstanbul',
        'tenant': 'Okan K.',
        'tenantPhone': '0535 777 88 99',
        'landlord': 'Erkan B.',
        'paymentCycle': 'Aylık',
        'rentAmount': 15000.0,
        'deposit': '30.000 TL',
        'status': 'Onay Bekliyor',
        'daskExpiry': '240 gün var',
      },
    ];
  }

  static List<Map<String, dynamic>> properties = [
    {
      'name': 'Şişli Daire (D:4)',
      'building': 'Güneş Apartmanı',
      'unit': 'Kat 2, Daire 4',
      'address': 'Halaskargazi Cad. No:112 D:4, Şişli / İstanbul',
      'tenant': 'Ali V.',
      'tenantPhone': '0532 111 22 33',
      'landlord': 'Erkan B.',
      'paymentCycle': 'Aylık',
      'rentAmount': 18000.0,
      'deposit': '36.000 TL',
      'status': 'Ödeme Bekliyor',
      'daskExpiry': '15 gün kaldı',
    },
    {
      'name': 'Şişli Daire (D:7)',
      'building': 'Güneş Apartmanı',
      'unit': 'Kat 4, Daire 7 (Ön Cephe)',
      'address': 'Halaskargazi Cad. No:112 D:7, Şişli / İstanbul',
      'tenant': 'Mehmet S.',
      'tenantPhone': '0533 444 55 66',
      'landlord': 'Erkan B.',
      'paymentCycle': '3 Aylık (Çeyreklik)',
      'rentAmount': 60000.0,
      'deposit': '60.000 TL',
      'status': 'Ödeme Bekliyor',
      'daskExpiry': '180 gün var',
    },
    {
      'name': 'Kadıköy Daire (D:2)',
      'building': 'Moda Palas',
      'unit': 'Giriş Kat, Daire 2',
      'address': 'Moda Cad. No:45 D:2, Kadıköy / İstanbul',
      'tenant': 'Okan K.',
      'tenantPhone': '0535 777 88 99',
      'landlord': 'Erkan B.',
      'paymentCycle': 'Aylık',
      'rentAmount': 15000.0,
      'deposit': '30.000 TL',
      'status': 'Onay Bekliyor',
      'daskExpiry': '240 gün var',
    },
  ];

  static String alertMessage =
      "⚠️ Şişli Daire (D:4) DASK poliçesi 15 gün içinde dolacak.";
}
