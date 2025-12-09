import 'package:flutter/material.dart';

class AvisoLegalPage extends StatelessWidget {
  const AvisoLegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aviso legal"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Aviso legal",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              Text(
                """
Esta aplicación tiene como finalidad brindar información general y permitir el acceso a datos de comercios, puntos de venta y distribuidoras. 

El uso de la aplicación implica la aceptación de los siguientes términos:

1. **Responsabilidad del contenido**
   La información mostrada es proporcionada por terceros. No garantizamos exactitud absoluta, disponibilidad permanente ni ausencia de errores.

2. **Privacidad**
   No recopilamos datos personales sin autorización previa. Cualquier dato brindado por el usuario es usado únicamente para mejorar la experiencia o responder consultas.

3. **Uso permitido**
   Está prohibido utilizar la app con fines maliciosos, automatizaciones agresivas o cualquier acción que afecte su funcionamiento.

4. **Propiedad intelectual**
   El diseño, marca, textos y funcionalidades pertenecen a los desarrolladores de esta aplicación. Su copia o modificación sin permiso está prohibida.

5. **Contacto**
   Ante cualquier duda o solicitud, podés escribirnos a:
   consultas@descabio.com
                """,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: cs.onSurface.withOpacity(0.9),
                    ),
              ),

              const SizedBox(height: 24),

              Center(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
