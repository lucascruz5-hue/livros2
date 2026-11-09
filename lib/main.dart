import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MeusLivrosApp());

enum Status { lido, desejado }

class Livro {
  String titulo;
  String autor;
  Status status;
  int nota;

  Livro({
    required this.titulo,
    required this.autor,
    required this.status,
    this.nota = 0,
  });

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'autor': autor,
        'status': status.name,
        'nota': nota,
      };

  factory Livro.fromJson(Map<String, dynamic> j) => Livro(
        titulo: j['titulo'] as String,
        autor: j['autor'] as String,
        status: Status.values.byName(j['status'] as String),
        nota: (j['nota'] ?? 0) as int,
      );
}

class MeusLivrosApp extends StatelessWidget {
  const MeusLivrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Livros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _chave = 'livros_v1';
  final List<Livro> _livros = [];
  final GlobalKey _rankingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chave);
    if (raw != null) {
      final lista = (jsonDecode(raw) as List)
          .map((e) => Livro.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _livros
        ..clear()
        ..addAll(lista));
    }
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _chave, jsonEncode(_livros.map((l) => l.toJson()).toList()));
  }

  Future<void> _abrirFormulario({Livro? livro, Status? statusInicial}) async {
    final tituloCtrl = TextEditingController(text: livro?.titulo ?? '');
    final autorCtrl = TextEditingController(text: livro?.autor ?? '');
    var status = livro?.status ?? statusInicial ?? Status.lido;
    var nota = livro?.nota ?? 0;
    var erroTitulo = false;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(livro == null ? 'Novo livro' : 'Editar livro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    errorText: erroTitulo ? 'Informe o título' : null,
                  ),
                ),
                TextField(
                  controller: autorCtrl,
                  decoration: const InputDecoration(labelText: 'Autor'),
                ),
                const SizedBox(height: 16),
                SegmentedButton<Status>(
                  segments: const [
                    ButtonSegment(value: Status.lido, label: Text('Lido')),
                    ButtonSegment(
                        value: Status.desejado, label: Text('Desejado')),
                  ],
                  selected: {status},
                  onSelectionChanged: (s) => setD(() => status = s.first),
                ),
                if (status == Status.lido) ...[
                  const SizedBox(height: 12),
                  const Text('Avaliação'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          i < nota ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setD(() => nota = i + 1),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () {
                  if (tituloCtrl.text.trim().isEmpty) {
                    setD(() => erroTitulo = true);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (salvou != true) return;

    setState(() {
      if (livro == null) {
        _livros.add(Livro(
          titulo: tituloCtrl.text.trim(),
          autor: autorCtrl.text.trim(),
          status: status,
          nota: status == Status.lido ? nota : 0,
        ));
      } else {
        livro
          ..titulo = tituloCtrl.text.trim()
          ..autor = autorCtrl.text.trim()
          ..status = status
          ..nota = status == Status.lido ? nota : 0;
      }
    });
    await _salvar();
  }

  void _excluir(Livro livro) {
    setState(() => _livros.remove(livro));
    _salvar();
  }

  List<Livro> get _top5 {
    final lidos = _livros
        .where((l) => l.status == Status.lido && l.nota > 0)
        .toList()
      ..sort((a, b) => b.nota.compareTo(a.nota));
    return lidos.take(5).toList();
  }

  Future<void> _compartilharRanking() async {
    try {
      final ctx = _rankingKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/top5_livros.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'Meu Top 5 de livros 📚');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao compartilhar: $e')));
    }
  }

  Widget _lista(Status status) {
    final itens = _livros.where((l) => l.status == status).toList();
    if (itens.isEmpty) {
      return Center(
        child: Text(status == Status.lido
            ? 'Nenhum livro lido ainda.'
            : 'Sua lista de desejos está vazia.'),
      );
    }
    return ListView.builder(
      itemCount: itens.length,
      itemBuilder: (_, i) {
        final l = itens[i];
        return Dismissible(
          key: ObjectKey(l),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _excluir(l),
          child: ListTile(
            leading: Icon(status == Status.lido
                ? Icons.check_circle
                : Icons.bookmark_border),
            title: Text(l.titulo),
            subtitle: Text(l.autor.isEmpty ? 'Autor desconhecido' : l.autor),
            trailing: status == Status.lido
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${l.nota}'),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                    ],
                  )
                : null,
            onTap: () => _abrirFormulario(livro: l),
          ),
        );
      },
    );
  }

  Widget _abaTop5() {
    final top = _top5;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: _rankingKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3949AB), Color(0xFF7E57C2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📚 Meu Top 5 Livros',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (top.isEmpty)
                      const Text(
                          'Avalie livros lidos (1 a 5 estrelas) para montar o ranking.',
                          style: TextStyle(color: Colors.white70)),
                    for (var i = 0; i < top.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}º ',
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(top[i].titulo,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600)),
                                  if (top[i].autor.isNotEmpty)
                                    Text(top[i].autor,
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  Text('★' * top[i].nota,
                                      style: const TextStyle(
                                          color: Colors.amber, fontSize: 16)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: top.isEmpty ? null : _compartilharRanking,
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar imagem'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        final tabController = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Meus Livros'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Lidos'),
              Tab(text: 'Desejados'),
              Tab(text: 'Top 5'),
            ]),
          ),
          body: TabBarView(
            children: [
              _lista(Status.lido),
              _lista(Status.desejado),
              _abaTop5(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _abrirFormulario(
              statusInicial:
                  tabController.index == 1 ? Status.desejado : Status.lido,
            ),
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }
}
