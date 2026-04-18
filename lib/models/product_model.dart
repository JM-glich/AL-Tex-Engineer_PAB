class Product {
  final String id;
  final String name;
  final int price;
  final String description;
  final String category;
  final String imageUrl;
  final int stock;
  final int sold; // Ganti bool isBestSeller menjadi int sold

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.stock,
    this.sold = 0, // Default terjual adalah 0
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      // id dari SQL kamu adalah integer, jadi kita pastikan jadi String
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      stock: json['stock'] ?? 0,
      sold: json['sold'] ?? 0, // Mapping kolom 'sold'
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'stock': stock,
      'sold': sold, // Mapping kolom 'sold'
    };

    if (id.isNotEmpty) {
      data['id'] = int.tryParse(id) ?? id; // Konversi balik ke int jika id adalah angka
    }
    
    return data;
  }
}