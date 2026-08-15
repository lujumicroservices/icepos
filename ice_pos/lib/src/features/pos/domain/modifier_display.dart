/// Etiquetas legibles para modificadores (sabores de boli, nieves, etc.) en ticket y UI.
class ModifierDisplay {
  ModifierDisplay._();

  /// Nombre corto para ticket (ej. "Nieve LECHE - Vainilla" → "Vainilla").
  static String ticketLabel(String supplyName) {
    final parsed = parse(supplyName);
    if (parsed.subgroup != null && parsed.subgroup!.isNotEmpty) {
      return '${parsed.subgroup}: ${parsed.displayName}';
    }
    return parsed.displayName;
  }

  static ({String? subgroup, String displayName}) parse(String supplyName) {
    if (supplyName.startsWith('Boli Regular - ')) {
      return (subgroup: 'Regular', displayName: supplyName.replaceFirst('Boli Regular - ', ''));
    }
    if (supplyName.startsWith('Boli Light - ')) {
      return (subgroup: 'Light', displayName: supplyName.replaceFirst('Boli Light - ', ''));
    }
    if (supplyName.startsWith('Paleta Agua - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Paleta Agua - ', ''));
    }
    if (supplyName.startsWith('Paleta Forrada - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Paleta Forrada - ', ''));
    }
    if (supplyName.startsWith('Nieve AGUA - ')) {
      return (subgroup: 'AGUA', displayName: supplyName.replaceFirst('Nieve AGUA - ', ''));
    }
    if (supplyName.startsWith('Nieve LECHE - ')) {
      return (subgroup: 'LECHE', displayName: supplyName.replaceFirst('Nieve LECHE - ', ''));
    }
    if (supplyName.startsWith('Nieve CREMA - ')) {
      return (subgroup: 'CREMA', displayName: supplyName.replaceFirst('Nieve CREMA - ', ''));
    }
    if (supplyName.startsWith('Nieve LIGHT - ')) {
      return (subgroup: 'LIGHT', displayName: supplyName.replaceFirst('Nieve LIGHT - ', ''));
    }
    if (supplyName.startsWith('Malteada - ')) {
      return (subgroup: null, displayName: supplyName.replaceFirst('Malteada - ', ''));
    }
    return (subgroup: null, displayName: supplyName);
  }
}
