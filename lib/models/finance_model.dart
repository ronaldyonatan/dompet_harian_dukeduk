enum TransactionType { income, expense }

class Category {
  final int? id;
  final String name;
  final TransactionType type;
  final bool isActive;
  final String? icon;

  Category({
    this.id,
    required this.name,
    required this.type,
    this.isActive = true,
    this.icon,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: TransactionType.values.byName(map['type']),
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      icon: map['icon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'is_active': isActive ? 1 : 0,
      'icon': icon,
    };
  }
}

class ItemModel {
  final int? id;
  final String name;
  final int categoryId;
  final String? barcode;
  final double? defaultPrice;
  final bool isActive;
  final String? icon;

  ItemModel({
    this.id,
    required this.name,
    required this.categoryId,
    this.barcode,
    this.defaultPrice,
    this.isActive = true,
    this.icon,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'],
      name: map['name'],
      categoryId: map['category_id'] ?? map['categoryId'],
      barcode: map['barcode'],
      defaultPrice: map['default_price'] is int
          ? (map['default_price'] as int).toDouble()
          : map['default_price'],
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      icon: map['icon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'barcode': barcode,
      'default_price': defaultPrice,
      'is_active': isActive ? 1 : 0,
      'icon': icon,
    };
  }
}

// --- MASTER CUSTOMER MODEL ---
class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;

  CustomerModel({this.id, required this.name, this.phone, this.address});

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone, 'address': address};
  }
}

// --- MASTER LENDER MODEL ---
class LenderModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;

  LenderModel({this.id, required this.name, this.phone, this.address});

  factory LenderModel.fromMap(Map<String, dynamic> map) {
    return LenderModel(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone, 'address': address};
  }
}

class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String date;
  final int categoryId;
  final int? itemId;
  final String? note;
  final String? categoryName;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.itemId,
    this.note,
    this.categoryName,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : map['amount'],
      date: map['date'],
      categoryId: map['category_id'] ?? map['categoryId'],
      itemId: map['item_id'] ?? map['itemId'],
      note: map['note'],
      categoryName: map['category_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date,
      'category_id': categoryId,
      'item_id': itemId,
      'note': note,
    };
  }
}

class BudgetModel {
  final int? id;
  final int categoryId;
  final int month;
  final int year;
  final double amount;

  BudgetModel({
    this.id,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'month': month,
      'year': year,
      'amount': amount,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'],
      month: map['month'],
      year: map['year'],
      categoryId: map['category_id'] ?? map['categoryId'] ?? 0,
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : (map['amount'] ?? 0.0),
    );
  }
}
