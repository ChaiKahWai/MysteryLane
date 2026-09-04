class CheckpointDestination {
  final String destinationId;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String? address;
  final String? popularityClassification;
  final String destinationSource;

  const CheckpointDestination({
    required this.destinationId,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.address,
    this.popularityClassification,
    required this.destinationSource,
  });

  factory CheckpointDestination.fromJson(
      Map<String, dynamic> json,
      ) {
    return CheckpointDestination(
      destinationId:
      json['destination_id'].toString(),

      name:
      json['name']?.toString() ?? '',

      description:
      json['description']?.toString(),

      category:
      json['category']?.toString(),

      imageUrl:
      json['image_url']?.toString(),

      latitude:
      double.parse(
        json['latitude'].toString(),
      ),

      longitude:
      double.parse(
        json['longitude'].toString(),
      ),

      address:
      json['address']?.toString(),

      popularityClassification:
      json['popularity_classification']
          ?.toString(),

      destinationSource:
      json['destination_source']
          ?.toString() ??
          'GOOGLE',
    );
  }
}