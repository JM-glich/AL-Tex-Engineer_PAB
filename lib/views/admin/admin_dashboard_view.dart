import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahan untuk validasi input angka
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../auth/login_view.dart';
import 'dart:typed_data';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final ProductController _controller = ProductController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua Kategori';
  String _selectedSort = 'Nama: A-Z';
  
  // Controller tetap dipertahankan
  final TextEditingController _searchController = TextEditingController();

  final Color primaryBlue = const Color(0xFF0284C7);
  final Color lightBlueBg = const Color(0xFFF0F9FF);

  final List<String> _categories = [
    'Semua Kategori', 'Semen', 'Pasir', 'Batu Bata', 'Cat Dinding', 
    'Kayu', 'Besi Steel', 'Pipa PVC', 'Keramik', 'Atap', 'Kunci & Engsel', 'Lainnya'
  ];

  final List<String> _sortOptions = [
    'Nama: A-Z', 'Nama: Z-A', 'Harga: Rendah-Tinggi', 'Harga: Tinggi-Rendah', 'Stok: Terbanyak'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatIDR(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Menampilkan Snackbar Notifikasi
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Dialog Konfirmasi Hapus
  Future<void> _confirmDeleteDialog(Product product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Konfirmasi Hapus'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus material "${product.name}"?\nData yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Batal', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _controller.deleteProduct(product.id);
        setState(() {}); // Refresh data
        if (mounted) _showSnackBar('Berhasil menghapus material "${product.name}"');
      } catch (e) {
        if (mounted) _showSnackBar('Gagal menghapus data: $e', isError: true);
      }
    }
  }

  Future<String?> _uploadImage(XFile pickedFile) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storage = Supabase.instance.client.storage.from('products');

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await storage.uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      } else {
        final file = File(pickedFile.path);
        await storage.upload(fileName, file);
      }
      return storage.getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error upload image: $e');
      return null;
    }
  }

  void _showProductDialog({Product? product}) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: isEdit ? product.name : '');
    final priceController = TextEditingController(text: isEdit ? product.price.toString() : '');
    final stockController = TextEditingController(text: isEdit ? product.stock.toString() : '');
    final soldController = TextEditingController(text: isEdit ? product.sold.toString() : '0'); 
    final descriptionController = TextEditingController(text: isEdit ? product.description : '');
    final imageUrlController = TextEditingController(text: isEdit ? product.imageUrl : '');
    
    String? selectedCategory = isEdit ? product.category : null;
    String existingImageUrl = isEdit ? product.imageUrl : '';
    
    XFile? selectedXFile; 
    Uint8List? webImageBytes; 
    bool isLoading = false;  
    bool isUploadMode = !isEdit; 
    
    final formKey = GlobalKey<FormState>(); // Tambahan untuk validasi form

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Edit Material' : 'Tambah Material'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isUploadMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isUploadMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Upload'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isUploadMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isUploadMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text('URL'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    height: 120, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100], 
                      borderRadius: BorderRadius.circular(10), 
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: _buildPreviewWidget(
                      selectedXFile, 
                      webImageBytes, 
                      isUploadMode ? existingImageUrl : imageUrlController.text, 
                      isEdit || !isUploadMode
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (isUploadMode) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                        if (pickedFile != null) {
                          if (kIsWeb) {
                            final bytes = await pickedFile.readAsBytes();
                            setDialogState(() { webImageBytes = bytes; selectedXFile = pickedFile; });
                          } else {
                            setDialogState(() => selectedXFile = pickedFile);
                          }
                        }
                      },
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Pilih Gambar Galeri'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: imageUrlController, 
                      decoration: const InputDecoration(labelText: 'URL Gambar', prefixIcon: Icon(Icons.link)),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                  ],
                  // Validasi Nama Barang (Hanya Huruf, Angka, dan Spasi)
                  TextFormField(
                    controller: nameController, 
                    decoration: const InputDecoration(labelText: 'Nama Barang *'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama barang wajib diisi';
                      }
                      // Regex untuk mengizinkan hanya huruf, angka, dan spasi
                      if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(value)) {
                        return 'Nama hanya boleh berisi huruf dan angka';
                      }
                      return null;
                    },
                  ),
                  // Validasi Harga (Hanya Angka dan Limit 1 Miliar)
                  TextFormField(
                    controller: priceController, 
                    decoration: const InputDecoration(labelText: 'Harga (Rp) *', hintText: 'Contoh: 50000'), 
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Harga wajib diisi dengan angka';
                      }
                      final price = int.tryParse(value);
                      if (price == null) {
                        return 'Format harga tidak valid';
                      }
                      if (price > 1000000000) {
                        return 'Maksimal harga Rp 1.000.000.000';
                      }
                      return null;
                    },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Validasi Stok (Hanya Angka dan Limit 10 Juta)
                      Expanded(
                        child: TextFormField(
                          controller: stockController, 
                          decoration: const InputDecoration(labelText: 'Stok *'), 
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Wajib diisi';
                            }
                            final stock = int.tryParse(value);
                            if (stock == null) {
                              return 'Format stok tidak valid';
                            }
                            if (stock > 10000000) {
                              return 'Maksimal stok 10 Juta';
                            }
                            return null;
                          },
                        )
                      ),
                      const SizedBox(width: 10),
                      // Validasi Terjual (Hanya Angka)
                      Expanded(
                        child: TextFormField(
                          controller: soldController, 
                          decoration: const InputDecoration(labelText: 'Terjual *'), 
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Validasi Kategori
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori *'),
                    items: _categories.where((cat) => cat != 'Semua Kategori').map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    validator: (value) => value == null ? 'Kategori wajib dipilih' : null,
                    onChanged: (val) => setDialogState(() => selectedCategory = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            isLoading 
              ? CircularProgressIndicator(color: primaryBlue)
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                  onPressed: () async {
                    // Cek validasi form
                    if (!formKey.currentState!.validate()) return;
                    
                    // Pop up konfirmasi simpan
                    bool? confirmSave = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        title: const Text('Konfirmasi Simpan'),
                        content: const Text('Apakah data yang dimasukkan sudah benar?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa Lagi')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                            onPressed: () => Navigator.pop(ctx, true), 
                            child: const Text('Ya, Simpan', style: TextStyle(color: Colors.white))
                          ),
                        ],
                      )
                    );

                    if (confirmSave != true) return;

                    setDialogState(() => isLoading = true);
                    
                    try {
                      String finalImageUrl = existingImageUrl;
                      if (isUploadMode && selectedXFile != null) {
                        final url = await _uploadImage(selectedXFile!);
                        if (url != null) finalImageUrl = url;
                      } else if (!isUploadMode) {
                        finalImageUrl = imageUrlController.text;
                      }

                      final prod = Product(
                        id: isEdit ? product.id : '',
                        name: nameController.text.trim(),
                        price: int.tryParse(priceController.text) ?? 0,
                        category: selectedCategory!,
                        description: descriptionController.text,
                        imageUrl: finalImageUrl,
                        stock: int.tryParse(stockController.text) ?? 0,
                        sold: int.tryParse(soldController.text) ?? 0, 
                      );
                      
                      isEdit ? await _controller.updateProduct(prod) : await _controller.addProduct(prod);
                      
                      if (mounted) { 
                        Navigator.pop(context); 
                        setState(() {}); 
                        _showSnackBar(isEdit ? 'Berhasil mengupdate material!' : 'Berhasil menambahkan material baru!');
                      }
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (mounted) _showSnackBar('Gagal menyimpan: $e', isError: true);
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewWidget(XFile? xFile, Uint8List? webBytes, String currentUrl, bool showUrlPreview) {
    if (kIsWeb && webBytes != null) return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(webBytes, fit: BoxFit.cover));
    if (!kIsWeb && xFile != null) return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(xFile.path), fit: BoxFit.cover));
    
    if (showUrlPreview && currentUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: currentUrl, 
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 30),
              SizedBox(height: 4),
              Text('URL Gambar Tidak Valid', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );
    }
    return const Icon(Icons.add_a_photo, color: Colors.grey, size: 30);
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()));
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.business_center, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Admin Dashboard', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Kelola Barang', style: TextStyle(color: primaryBlue, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
      actions: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Admin User', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('Administrator', style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: _logout,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(border: Border.all(color: primaryBlue.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.logout, color: primaryBlue, size: 18),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildStatCards(List<Product> products) {
    int totalItems = products.length;
    int totalStock = products.fold(0, (sum, item) => sum + item.stock);
    int totalSold = products.fold(0, (sum, item) => sum + item.sold);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _statCard('Barang', totalItems.toString(), Icons.inventory_2, primaryBlue),
          const SizedBox(width: 10),
          _statCard('Stok', totalStock.toString(), Icons.layers, Colors.green),
          const SizedBox(width: 10),
          _statCard('Terjual', totalSold.toString(), Icons.shopping_cart, Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController, 
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari material...',
              prefixIcon: Icon(Icons.search, color: primaryBlue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue.withOpacity(0.1))),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryBlue.withOpacity(0.2))
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: Icon(Icons.filter_list, size: 16, color: primaryBlue),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryBlue.withOpacity(0.2))
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      icon: Icon(Icons.sort, size: 16, color: primaryBlue),
                      items: _sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _selectedSort = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _showProductDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue, 
                  foregroundColor: Colors.white, 
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)
                ),
                child: const Icon(Icons.add, size: 20),
              )
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FutureBuilder<List<Product>>(
        future: _controller.getProducts(searchQuery: _searchQuery),
        builder: (context, snapshot) {
          var allProducts = snapshot.data ?? [];
          
          var filteredProducts = List<Product>.from(allProducts);
          if (_selectedCategory != 'Semua Kategori') {
            filteredProducts = filteredProducts.where((p) => p.category == _selectedCategory).toList();
          }

          if (_selectedSort == 'Nama: A-Z') filteredProducts.sort((a, b) => a.name.compareTo(b.name));
          if (_selectedSort == 'Nama: Z-A') filteredProducts.sort((a, b) => b.name.compareTo(a.name));
          if (_selectedSort == 'Harga: Rendah-Tinggi') filteredProducts.sort((a, b) => a.price.compareTo(b.price));
          if (_selectedSort == 'Harga: Tinggi-Rendah') filteredProducts.sort((a, b) => b.price.compareTo(a.price));
          if (_selectedSort == 'Stok: Terbanyak') filteredProducts.sort((a, b) => b.stock.compareTo(a.stock));

          return Column(
            children: [
              _buildStatCards(allProducts),
              _buildFilterSection(),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? Center(child: CircularProgressIndicator(color: primaryBlue))
                    : filteredProducts.isEmpty 
                        ? const Center(child: Text("Barang tidak ditemukan"))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) => _buildProductCard(filteredProducts[index]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: lightBlueBg, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: product.imageUrl, 
            width: 50, height: 50, 
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.white),
            errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
          ),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatIDR(product.price), style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                _badge('Stok: ${product.stock}', Colors.orange),
                const SizedBox(width: 8),
                _badge('Terjual: ${product.sold}', primaryBlue),
              ],
            )
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, size: 20),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
          ],
          onSelected: (val) {
            if (val == 'edit') {
              _showProductDialog(product: product);
            } else if (val == 'delete') {
              _confirmDeleteDialog(product);
            }
          },
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), 
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}