import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../auth/login_view.dart';
import 'product_detail_view.dart';

class UserDashboardView extends StatefulWidget {
  final String? userName;
  const UserDashboardView({super.key, this.userName});

  @override
  State<UserDashboardView> createState() => _UserDashboardViewState();
}

class _UserDashboardViewState extends State<UserDashboardView> {
  final ProductController _controller = ProductController();
  
  String _searchQuery = '';
  String _selectedCategory = 'Semua Kategori';
  String _selectedSort = 'Paling Populer';
  String _userName = 'Guest';

  final List<String> _categories = [
    'Semua Kategori', 'Semen', 'Pasir', 'Batu Bata', 'Cat Dinding', 
    'Kayu', 'Besi Steel', 'Pipa PVC', 'Keramik', 'Atap', 
    'Kunci & Engsel', 'Alat Pertukangan', 'Lainnya'
  ];

  final List<String> _sortOptions = [
    'Paling Populer',
    'Nama: A-Z',
    'Nama: Z-A',
    'Harga: Rendah-Tinggi',
    'Harga: Tinggi-Rendah',
    'Stok: Sedikit-Banyak',
    'Stok: Banyak-Sedikit'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  void _fetchUserName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.userMetadata?['full_name'] ?? 
                    user.email?.split('@')[0] ?? 
                    'User';
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()));
    }
  }

  String formatRupiah(int price) {
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // APP BAR - Updated Alignment
          SliverAppBar(
            expandedHeight: 160.0,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0284C7),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false, // Set ke false untuk rata kiri
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                children: [
                  Text(
                    'FAKTA INDAH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    'Pusat Material Bangunan Terlengkap',
                    style: TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1504307651254-35680f356dfd?q=80&w=2070&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.lightBlue.withOpacity(0.2),
                          const Color(0xFF0284C7).withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _userName == 'Guest' ? 'User Account' : 'Regular User',
                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // NEW: SUMMARY WIDGET (Total Barang, Stok, Terjual)
          SliverToBoxAdapter(
            child: _buildSummaryCards(),
          ),

          // SEARCH & FILTER DROPDOWN
          SliverToBoxAdapter(
            child: _buildSearchAndFilter(),
          ),

          // SECTION 1: BEST SELLER
          if (_searchQuery.isEmpty && _selectedCategory == 'Semua Kategori' && _selectedSort == 'Paling Populer') ...[
            SliverToBoxAdapter(child: _buildSectionTitle('REKOMENDASI TERLARIS (TOP 5)')),
            SliverToBoxAdapter(child: _buildBestSellerSection()),
          ],

          // SECTION 2: DAFTAR PRODUK UTAMA
          SliverToBoxAdapter(
            child: _buildSectionTitle(
              _searchQuery.isEmpty ? 'Katalog Barang' : 'Hasil Pencarian',
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildProductCatalog(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // Widget Summary Cards Baru
  Widget _buildSummaryCards() {
    return FutureBuilder<List<Product>>(
      future: _controller.getProducts(searchQuery: ''),
      builder: (context, snapshot) {
        int totalItems = 0;
        int totalStock = 0;
        int totalSold = 0;

        if (snapshot.hasData) {
          totalItems = snapshot.data!.length;
          for (var p in snapshot.data!) {
            totalStock += p.stock;
            totalSold += p.sold;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              _cardInfo('Total Barang', totalItems.toString(), Icons.inventory_2_rounded, Colors.blue),
              const SizedBox(width: 8),
              _cardInfo('Total Stok', totalStock.toString(), Icons.layers_rounded, Colors.orange),
              const SizedBox(width: 8),
              _cardInfo('Total Terjual', totalSold.toString(), Icons.shopping_bag_rounded, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _cardInfo(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari barang...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) setState(() => _selectedCategory = newValue);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSort,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                      items: _sortOptions.map((String sort) {
                        return DropdownMenuItem<String>(
                          value: sort,
                          child: Text(sort, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) setState(() => _selectedSort = newValue);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: const Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellerSection() {
    return SizedBox(
      height: 240, 
      child: FutureBuilder<List<Product>>(
        future: _controller.getProducts(searchQuery: '', sortByMostSold: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada produk terlaris"));
          }
          final products = snapshot.data!;
          final displayCount = products.length > 5 ? 5 : products.length;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: displayCount,
            itemBuilder: (context, index) => _buildProductCard(products[index], isHorizontal: true),
          );
        },
      ),
    );
  }

  Widget _buildProductCatalog() {
    return FutureBuilder<List<Product>>(
      future: _controller.getProducts(searchQuery: _searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        
        final allProducts = snapshot.data ?? [];
        List<Product> products = [];

        // Filter Kategori
        if (_selectedCategory == 'Semua Kategori') {
          products = List.from(allProducts);
        } else if (_selectedCategory == 'Lainnya') {
          final mainCategories = ['Semen', 'Pasir', 'Batu Bata', 'Cat Dinding', 'Kayu', 'Besi Steel', 'Pipa PVC', 'Keramik', 'Atap', 'Kunci & Engsel'];
          products = allProducts.where((p) {
            return !mainCategories.any((cat) => cat.toLowerCase() == p.category.trim().toLowerCase());
          }).toList();
        } else {
          products = allProducts.where((p) => 
            p.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase()
          ).toList();
        }

        // Logic Sorting Baru (Termasuk Stok)
        if (_selectedSort == 'Nama: A-Z') {
          products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        } else if (_selectedSort == 'Nama: Z-A') {
          products.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        } else if (_selectedSort == 'Harga: Rendah-Tinggi') {
          products.sort((a, b) => a.price.compareTo(b.price));
        } else if (_selectedSort == 'Harga: Tinggi-Rendah') {
          products.sort((a, b) => b.price.compareTo(a.price));
        } else if (_selectedSort == 'Paling Populer') {
          products.sort((a, b) => b.sold.compareTo(a.sold));
        } else if (_selectedSort == 'Stok: Sedikit-Banyak') {
          products.sort((a, b) => a.stock.compareTo(b.stock));
        } else if (_selectedSort == 'Stok: Banyak-Sedikit') {
          products.sort((a, b) => b.stock.compareTo(a.stock));
        }

        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Produk tidak ditemukan.'))),
          );
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.70, 
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildProductCard(products[index]),
            childCount: products.length,
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, {bool isHorizontal = false}) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailView(product: product)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isHorizontal ? 170 : double.infinity,
        margin: isHorizontal ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Hero(
                  tag: 'prod-img-${product.id}',
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.category.toUpperCase(), style: const TextStyle(color: Color(0xFF0284C7), fontSize: 9, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), height: 1.2)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatRupiah(product.price), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${product.sold} Terjual", style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            Text("Stok: ${product.stock}", style: TextStyle(fontSize: 9, color: product.stock < 5 ? Colors.red : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}