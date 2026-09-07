class Product {
  final String id;
  final String name;
  final String? sku;
  final String? description;
  final String? supplierId;
  final String? supplierName;
  final String category;
  final String? barcode;
  final double unitPrice;
  final double wholesalePrice;
  final String unit;
  final int currentStock;
  final int minStock;
  final int maxStock;
  final String? imageUrl;
  final bool isActive;

  // Book / school-item specific metadata (optional)
  final String? author;
  final String? publisher;
  final String? isbn;
  final String? edition;
  final String? gradeLevel;
  final String? subject;
  final String? language;
  final int? pageCount;

  Product({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    this.supplierId,
    this.supplierName,
    required this.category,
    this.barcode,
    required this.unitPrice,
    required this.wholesalePrice,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.maxStock,
    this.imageUrl,
    this.isActive = true,
    this.author,
    this.publisher,
    this.isbn,
    this.edition,
    this.gradeLevel,
    this.subject,
    this.language,
    this.pageCount,
  });

  bool get isLowStock => currentStock <= minStock && currentStock > 0;
  bool get isOutOfStock => currentStock <= 0;

  bool get isBook => category.toLowerCase() == 'books';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'description': description,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'category': category,
        'barcode': barcode,
        'unitPrice': unitPrice,
        'wholesalePrice': wholesalePrice,
        'unit': unit,
        'currentStock': currentStock,
        'minStock': minStock,
        'maxStock': maxStock,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'author': author,
        'publisher': publisher,
        'isbn': isbn,
        'edition': edition,
        'gradeLevel': gradeLevel,
        'subject': subject,
        'language': language,
        'pageCount': pageCount,
      };

  factory Product.fromMap(Map<dynamic, dynamic> map) => Product(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        sku: _optStr(map['sku']),
        description: _optStr(map['description']),
        supplierId: _optStr(map['supplierId']),
        supplierName: _optStr(map['supplierName']),
        category: (map['category'] ?? '').toString(),
        barcode: _optStr(map['barcode']),
        unitPrice: _parseDouble(map['unitPrice']),
        wholesalePrice: _parseDouble(map['wholesalePrice']),
        unit: (map['unit'] ?? '').toString(),
        currentStock: _parseInt(map['currentStock']),
        minStock: _parseInt(map['minStock']),
        maxStock: _parseInt(map['maxStock']),
        imageUrl: _optStr(map['imageUrl']),
        isActive: map['isActive'] == true,
        author: _optStr(map['author']),
        publisher: _optStr(map['publisher']),
        isbn: _optStr(map['isbn']),
        edition: _optStr(map['edition']),
        gradeLevel: _optStr(map['gradeLevel']),
        subject: _optStr(map['subject']),
        language: _optStr(map['language']),
        pageCount: _parseInt(map['pageCount']),
      );

  static String? _optStr(dynamic v) =>
      v == null ? null : v.toString().isEmpty ? null : v.toString();

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? description,
    String? supplierId,
    String? supplierName,
    String? category,
    String? barcode,
    double? unitPrice,
    double? wholesalePrice,
    String? unit,
    int? currentStock,
    int? minStock,
    int? maxStock,
    String? imageUrl,
    bool? isActive,
    String? author,
    String? publisher,
    String? isbn,
    String? edition,
    String? gradeLevel,
    String? subject,
    String? language,
    int? pageCount,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      unitPrice: unitPrice ?? this.unitPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      edition: edition ?? this.edition,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subject: subject ?? this.subject,
      language: language ?? this.language,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}