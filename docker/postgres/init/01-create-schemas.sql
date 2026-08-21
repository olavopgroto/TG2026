-- Arquitetura Medalhão: separação em camadas de maturidade dos dados
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

COMMENT ON SCHEMA bronze IS 'Dados brutos, exatamente como extraídos das fontes (Wikimedia API, eventos)';
COMMENT ON SCHEMA silver IS 'Dados limpos, tratados e padronizados';
COMMENT ON SCHEMA gold IS 'Dados finais em esquema estrela, prontos para análise no Power BI';