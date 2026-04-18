import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class ProductController {
  final _supabase = Supabase.instance.client;

  Future<List<Product>> getProducts({
    String searchQuery = '', 
    bool sortByMostSold = false // Nama parameter lebih relevan
  }) async {
    try {
      var query = _supabase.from('products').select();

      if (searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      final List<dynamic> response;
      
      if (sortByMostSold) {
        // Jika minta yang terlaris, urutkan berdasarkan 'sold' terbesar
        response = await query.order('sold', ascending: false);
      } else {
        // Default urutkan berdasarkan produk terbaru
        response = await query.order('created_at', ascending: false);
      }

      return response.map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('Error Fetching Products: $e');
      return []; 
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final data = product.toJson();
      if (product.id.isEmpty) {
        data.remove('id'); 
      }
      await _supabase.from('products').insert(data);
    } catch (e) {
      print('Error Adding Product: $e');
      rethrow; 
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);
    } catch (e) {
      print('Error Updating Product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      print('Error Deleting Product: $e');
      rethrow;
    }
  }
}