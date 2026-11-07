import Foundation

/// Fixed Core ML conversions linked by U²-Net's authors; verify every asset before installation.
enum SegmentationModelCatalog {
    static let recommendedID = "u2netp"
    static let models: [DownloadableSegmentationModel] = [
        DownloadableSegmentationModel(
            id: "u2netp", title: "U²-NetP", summary: "Kleines, schnelles Modell für allgemeine Vordergrundobjekte. Als ersten Versuch für die Live-Kamera empfohlen.",
            downloadURL: URL(string: "https://drive.usercontent.google.com/download?id=1D-quPGy33PzSEC6A7EBNv7mCyuiBlO08&export=download")!,
            sourceURL: URL(string: "https://github.com/john-rocky/CoreML-Models#u2net")!,
            license: "Apache-2.0", byteCount: 4_577_519,
            sha256: "f35a951dbb767d8434feafa490a28bb04c9cbcdbcace59b567b246efa3ca9551", fileName: "U2NetP.mlmodel"
        ),
        DownloadableSegmentationModel(
            id: "u2net", title: "U²-Net", summary: "Größere Variante für allgemeine Vordergrundobjekte. Für einen Qualitätsvergleich; benötigt mehr Speicher und Rechenleistung.",
            downloadURL: URL(string: "https://drive.usercontent.google.com/download?id=1cpm-x12Ih7Cqd_kOjfTvtt4ipGS3BpCx&export=download&confirm=t")!,
            sourceURL: URL(string: "https://github.com/john-rocky/CoreML-Models#u2net")!,
            license: "Apache-2.0", byteCount: 175_947_693,
            sha256: "51be4ce4c2d12177bc82e79d5cbb0dee25684f37f866cda6701ae7804ba003d6", fileName: "U2Net.mlmodel"
        )
    ]
}
