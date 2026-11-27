import React, { useState } from 'react';
import {
  GODOT_PROJECT_FILES,
  GodotProjectFile,
  buildGodotProjectZipBytes,
} from '../game/godotExporter';

interface GodotExportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const GodotExportModal: React.FC<GodotExportModalProps> = ({ isOpen, onClose }) => {
  const [selectedFileIndex, setSelectedFileIndex] = useState<number>(0);
  const [copiedPath, setCopiedPath] = useState<string | null>(null);
  const [downloadStatus, setDownloadStatus] = useState<string | null>(null);

  if (!isOpen) return null;

  const activeFile: GodotProjectFile =
    GODOT_PROJECT_FILES[selectedFileIndex] || GODOT_PROJECT_FILES[0];

  const handleDownloadZip = () => {
    const zipBytes = buildGodotProjectZipBytes(GODOT_PROJECT_FILES);
    const blob = new Blob([zipBytes.buffer as ArrayBuffer], { type: 'application/zip' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'RelicGrid_Godot4_Project.zip';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(() => URL.revokeObjectURL(url), 2500);
    setDownloadStatus('RelicGrid_Godot4_Project.zip indirildi! (Godot 4.3+ ile içe aktarın)');
  };

  const handleDownloadSingleFile = (file: GodotProjectFile) => {
    const blob = new Blob([file.content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    const baseName = file.path.split('/').pop() || 'file.gd';
    link.download = baseName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    setTimeout(() => URL.revokeObjectURL(url), 2500);
    setDownloadStatus(`${baseName} indirildi!`);
  };

  const handleCopyCode = async (file: GodotProjectFile) => {
    try {
      await navigator.clipboard.writeText(file.content);
      setCopiedPath(file.path);
      setTimeout(() => setCopiedPath(null), 2000);
    } catch {
      setCopiedPath(file.path);
      setTimeout(() => setCopiedPath(null), 2000);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Godot 4.3 Engine Export Studio"
      className="fixed inset-0 z-40 flex items-center justify-center p-3 sm:p-5 bg-black/80 pointer-events-auto"
    >
      <div className="w-full max-w-4xl max-h-[90vh] flex flex-col rounded-2xl bg-[#081611] border-2 border-[#478CBF] shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-3.5 bg-[#0B1F18] border-b border-[#1E4435]">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#478CBF]/20 border border-[#478CBF] flex items-center justify-center text-[#7CC4FA] font-extrabold text-sm font-mono-tabular">
              G4
            </div>
            <div>
              <h2 className="font-display text-lg sm:text-xl font-extrabold text-white tracking-wide">
                Godot 4.3+ Proje & Kaynak Kod Paketi
              </h2>
              <p className="text-xs text-emerald-200/80">
                GDScript 2.0 Kuralları · 60 FPS Özel <code className="text-amber-300">_draw()</code>{' '}
                Hayalet Projeksiyonu · Android / iOS / Web Profilleri
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleDownloadZip}
              className="px-4 py-2 rounded-xl bg-[#478CBF] hover:bg-[#5BA0D4] text-white font-bold text-xs sm:text-sm cursor-pointer transition-colors shadow-lg"
            >
              Godot 4 Projesini İndir (.ZIP)
            </button>
            <button
              type="button"
              onClick={onClose}
              aria-label="Close Godot Export Modal"
              className="px-3 py-2 rounded-xl bg-[#102920] hover:bg-[#193D30] border border-[#245442] text-emerald-100 font-bold text-xs cursor-pointer transition-colors"
            >
              Kapat [ESC]
            </button>
          </div>
        </div>

        {/* Quick Setup Steps Strip */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 px-5 py-2.5 bg-[#06110D] border-b border-[#17362A] text-xs">
          <div className="p-2.5 rounded-xl bg-[#0B1C15] border border-[#193A2D]">
            <span className="font-bold text-[#7CC4FA]">1. ZIP İndir & Çıkart:</span>{' '}
            <span className="text-emerald-100/85">
              Yukarıdaki butonla <code className="text-amber-300">RelicGrid_Godot4_Project.zip</code>{' '}
              arşivini indirin veya <code className="text-amber-300">/godot_project</code> klasörünü
              kullanın.
            </span>
          </div>
          <div className="p-2.5 rounded-xl bg-[#0B1C15] border border-[#193A2D]">
            <span className="font-bold text-[#7CC4FA]">2. Godot 4&apos;e Aktar:</span>{' '}
            <span className="text-emerald-100/85">
              Godot 4.3+ Proje Yöneticisi&apos;nde <strong>Import</strong> diyerek{' '}
              <code className="text-amber-300">project.godot</code> dosyasını seçin.
            </span>
          </div>
          <div className="p-2.5 rounded-xl bg-[#0B1C15] border border-[#193A2D]">
            <span className="font-bold text-[#7CC4FA]">3. Çalıştır & APK Çıkar:</span>{' '}
            <span className="text-emerald-100/85">
              <strong>F5</strong> ile oyunu başlatın veya{' '}
              <strong>Project → Export → Android / Web</strong> ile paketleyin.
            </span>
          </div>
        </div>

        {downloadStatus && (
          <div className="px-5 py-2 bg-emerald-950/90 border-b border-emerald-500/40 text-emerald-200 text-xs font-semibold flex items-center justify-between">
            <span>{downloadStatus}</span>
            <button
              type="button"
              onClick={() => setDownloadStatus(null)}
              className="text-emerald-300 hover:text-white underline text-[11px] cursor-pointer"
            >
              Tamam
            </button>
          </div>
        )}

        {/* File Tabs + Code Inspector */}
        <div className="flex-1 min-h-0 flex flex-col sm:flex-row overflow-hidden">
          {/* Sidebar File Tree */}
          <div className="w-full sm:w-64 bg-[#06110D] border-b sm:border-b-0 sm:border-r border-[#17362A] p-3 flex sm:flex-col gap-1.5 overflow-x-auto sm:overflow-y-auto shrink-0">
            <div className="hidden sm:block text-[10px] font-bold uppercase tracking-wider text-emerald-400/75 px-2 pb-1">
              res:// Dosya Ağacı ({GODOT_PROJECT_FILES.length})
            </div>
            {GODOT_PROJECT_FILES.map((file, idx) => {
              const selected = idx === selectedFileIndex;
              return (
                <button
                  key={file.path}
                  type="button"
                  onClick={() => setSelectedFileIndex(idx)}
                  className={`text-left px-3 py-2 rounded-xl text-xs font-mono-tabular transition-colors cursor-pointer shrink-0 ${
                    selected
                      ? 'bg-[#478CBF]/25 border border-[#478CBF] text-white font-bold'
                      : 'bg-[#0A1A14] hover:bg-[#112A20] border border-transparent text-emerald-200/80'
                  }`}
                >
                  <div className="truncate">{file.label}</div>
                </button>
              );
            })}
          </div>

          {/* Active File Content Viewer */}
          <div className="flex-1 min-h-0 flex flex-col bg-[#040B08]">
            <div className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5 bg-[#091813] border-b border-[#17362A]">
              <div>
                <div className="text-xs font-bold font-mono-tabular text-[#7CC4FA]">
                  res://{activeFile.path}
                </div>
                <div className="text-[11px] text-emerald-200/75">{activeFile.description}</div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => handleCopyCode(activeFile)}
                  className="px-3 py-1.5 rounded-lg bg-[#102920] hover:bg-[#183C2F] border border-[#245442] text-emerald-100 text-xs font-semibold cursor-pointer transition-colors"
                >
                  {copiedPath === activeFile.path ? 'Kopyalandı!' : 'Kodu Kopyala'}
                </button>
                <button
                  type="button"
                  onClick={() => handleDownloadSingleFile(activeFile)}
                  className="px-3 py-1.5 rounded-lg bg-[#14293A] hover:bg-[#1D3B52] border border-[#478CBF]/60 text-[#9AD4FF] text-xs font-semibold cursor-pointer transition-colors"
                >
                  Dosyayı İndir
                </button>
              </div>
            </div>

            <pre className="flex-1 p-4 overflow-auto text-xs font-mono-tabular text-emerald-100/95 leading-relaxed select-text">
              <code>{activeFile.content}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
};
