class Product {
  final String id;
  final String name;
  final String? sku;
  final String? description;
  final String supplierId;
  final String supplierName;
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
    required this.supplierId,
    required this.supplierName,
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