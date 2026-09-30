import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const VentasApp());

class VentasApp extends StatelessWidget {
  const VentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF176B5B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clientes | Tienda',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAF9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F6F4),
        useMaterial3: true,
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFE5F2EE)),
          headingTextStyle: TextStyle(
            color: Color(0xFF17463D),
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: TextStyle(color: Color(0xFF24342F)),
          dividerThickness: 0.7,
        ),
      ),
      home: const ClientesPage(),
    );
  }
}

class Cliente {
  const Cliente({
    required this.codigo,
    required this.dni,
    required this.nombre,
    required this.telefono,
    required this.direccion,
  });

  final int codigo;
  final String dni;
  final String nombre;
  final String telefono;
  final String direccion;

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      codigo: int.parse(json['codcliente'].toString()),
      dni: json['dni']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
    );
  }
}

class ClienteApi {
  static const _configuredEndpoint = String.fromEnvironment('API_URL');

  static String get endpoint {
    if (_configuredEndpoint.isNotEmpty) {
      return _configuredEndpoint;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/apicliente/api.php';
    }
    return 'http://127.0.0.1:8080/apicliente/api.php';
  }

  static Future<List<Cliente>> obtenerClientes() async {
    final response = await http
        .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'El servidor respondió con código ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('La respuesta del servidor no es una lista.');
    }

    return decoded
        .map((item) => Cliente.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  late Future<List<Cliente>> _clientes;

  @override
  void initState() {
    super.initState();
    _clientes = ClienteApi.obtenerClientes();
  }

  void _recargar() {
    setState(() => _clientes = ClienteApi.obtenerClientes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded),
            SizedBox(width: 12),
            Text('Clientes de la tienda'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FutureBuilder<List<Cliente>>(
                future: _clientes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingState();
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      error: snapshot.error,
                      onRetry: _recargar,
                    );
                  }

                  final clientes = snapshot.data ?? const <Cliente>[];
                  if (clientes.isEmpty) {
                    return _EmptyState(onRefresh: _recargar);
                  }

                  return _ClientesTable(clientes: clientes);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientesTable extends StatelessWidget {
  const _ClientesTable({required this.clientes});

  final List<Cliente> clientes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${clientes.length} ${clientes.length == 1 ? 'cliente registrado' : 'clientes registrados'}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF52635E),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFDCE6E2)),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 38,
                    horizontalMargin: 24,
                    columns: const [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('DNI')),
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Teléfono')),
                      DataColumn(label: Text('Dirección')),
                    ],
                    rows: clientes.map((cliente) {
                      return DataRow(
                        cells: [
                          DataCell(Text(cliente.codigo.toString())),
                          DataCell(Text(cliente.dni)),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 180),
                              child: Text(cliente.nombre),
                            ),
                          ),
                          DataCell(Text(cliente.telefono)),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 220,
                                maxWidth: 360,
                              ),
                              child: Text(
                                cliente.direccion,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando clientes...'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pudimos cargar los clientes',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Comprueba que Laragon y MySQL estén iniciados.\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 56),
          const SizedBox(height: 12),
          Text(
            'Aún no hay clientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
