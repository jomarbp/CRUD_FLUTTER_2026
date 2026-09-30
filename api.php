<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/config.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    $method = $_SERVER['REQUEST_METHOD'];
    $input = readJsonBody();

    switch ($method) {
        case 'GET':
            isset($_GET['id'])
                ? getCliente($db, (int) $_GET['id'])
                : getClientes($db);
            break;
        case 'POST':
            createCliente($db, $input);
            break;
        case 'PUT':
            updateCliente($db, $input);
            break;
        case 'DELETE':
            deleteCliente($db, getRequiredId($input));
            break;
        default:
            sendError(405, 'METHOD_NOT_ALLOWED', 'Método HTTP no permitido.');
    }
} catch (InvalidArgumentException $exception) {
    sendError(400, 'VALIDATION_ERROR', $exception->getMessage());
} catch (PDOException $exception) {
    sendError(500, 'DATABASE_ERROR', 'No se pudo completar la operación en la base de datos.');
} catch (Throwable $exception) {
    sendError(500, 'INTERNAL_ERROR', 'Ocurrió un error interno en el servidor.');
}

function getClientes(PDO $db): void
{
    $stmt = $db->query(
        'SELECT codcliente, dni, nombre, telefono, direccion
         FROM cliente
         ORDER BY codcliente DESC'
    );
    sendJson(200, $stmt->fetchAll());
}

function getCliente(PDO $db, int $id): void
{
    if ($id <= 0) {
        throw new InvalidArgumentException('El id del cliente no es válido.');
    }

    $stmt = $db->prepare(
        'SELECT codcliente, dni, nombre, telefono, direccion
         FROM cliente
         WHERE codcliente = ?'
    );
    $stmt->execute([$id]);
    $cliente = $stmt->fetch();

    if (!$cliente) {
        sendError(404, 'CLIENT_NOT_FOUND', 'Cliente no encontrado.');
    }
    sendJson(200, $cliente);
}

function createCliente(PDO $db, array $data): void
{
    $cliente = validateCliente($data);
    $exists = $db->prepare('SELECT 1 FROM cliente WHERE codcliente = ? OR dni = ? LIMIT 1');
    $exists->execute([$cliente['codcliente'], $cliente['dni']]);

    if ($exists->fetchColumn()) {
        sendError(409, 'CLIENT_ALREADY_EXISTS', 'Ya existe un cliente con ese código o DNI.');
    }

    $stmt = $db->prepare(
        'INSERT INTO cliente (codcliente, dni, nombre, telefono, direccion)
         VALUES (?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $cliente['codcliente'],
        $cliente['dni'],
        $cliente['nombre'],
        $cliente['telefono'],
        $cliente['direccion'],
    ]);

    sendJson(201, [
        'message' => 'Cliente creado exitosamente.',
        'codcliente' => $cliente['codcliente'],
    ]);
}

function updateCliente(PDO $db, array $data): void
{
    $cliente = validateCliente($data);
    $stmt = $db->prepare(
        'UPDATE cliente
         SET dni = ?, nombre = ?, telefono = ?, direccion = ?
         WHERE codcliente = ?'
    );
    $stmt->execute([
        $cliente['dni'],
        $cliente['nombre'],
        $cliente['telefono'],
        $cliente['direccion'],
        $cliente['codcliente'],
    ]);

    if ($stmt->rowCount() === 0 && !clienteExists($db, $cliente['codcliente'])) {
        sendError(404, 'CLIENT_NOT_FOUND', 'Cliente no encontrado.');
    }
    sendJson(200, ['message' => 'Cliente actualizado exitosamente.']);
}

function deleteCliente(PDO $db, int $id): void
{
    $stmt = $db->prepare('DELETE FROM cliente WHERE codcliente = ?');
    $stmt->execute([$id]);

    if ($stmt->rowCount() === 0) {
        sendError(404, 'CLIENT_NOT_FOUND', 'Cliente no encontrado.');
    }
    sendJson(200, ['message' => 'Cliente eliminado exitosamente.']);
}

function validateCliente(array $data): array
{
    foreach (['codcliente', 'dni', 'nombre', 'telefono', 'direccion'] as $field) {
        if (!array_key_exists($field, $data) || trim((string) $data[$field]) === '') {
            throw new InvalidArgumentException("El campo {$field} es obligatorio.");
        }
    }

    $id = (int) $data['codcliente'];
    $dni = trim((string) $data['dni']);
    $nombre = trim((string) $data['nombre']);
    $telefono = trim((string) $data['telefono']);
    $direccion = trim((string) $data['direccion']);

    if ($id <= 0) {
        throw new InvalidArgumentException('codcliente debe ser un entero positivo.');
    }
    if (!preg_match('/^\d{8}$/', $dni)) {
        throw new InvalidArgumentException('El DNI debe contener exactamente 8 dígitos.');
    }
    if (mb_strlen($nombre) > 80 || mb_strlen($telefono) > 12 || mb_strlen($direccion) > 120) {
        throw new InvalidArgumentException('Uno o más campos exceden la longitud permitida.');
    }

    return [
        'codcliente' => $id,
        'dni' => $dni,
        'nombre' => $nombre,
        'telefono' => $telefono,
        'direccion' => $direccion,
    ];
}

function getRequiredId(array $data): int
{
    $id = (int) ($data['codcliente'] ?? $data['id'] ?? 0);
    if ($id <= 0) {
        throw new InvalidArgumentException('Debe enviar un codcliente válido.');
    }
    return $id;
}

function clienteExists(PDO $db, int $id): bool
{
    $stmt = $db->prepare('SELECT 1 FROM cliente WHERE codcliente = ?');
    $stmt->execute([$id]);
    return (bool) $stmt->fetchColumn();
}

function readJsonBody(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $data = json_decode($raw, true);
    if (!is_array($data)) {
        throw new InvalidArgumentException('El cuerpo de la solicitud debe ser JSON válido.');
    }
    return $data;
}

function sendJson(int $status, mixed $data): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function sendError(int $status, string $code, string $message, array $details = []): never
{
    sendJson($status, [
        'error' => [
            'code' => $code,
            'message' => $message,
            'details' => $details,
        ],
    ]);
}
